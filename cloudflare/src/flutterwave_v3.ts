/**
 * Flutterwave v3 Standard — the hosted checkout.
 *
 * WEA describes the payment; Flutterwave hosts the page that collects it. The
 * payer is sent to a checkout carrying every method the academy's account
 * supports, with card first, and comes back with a result WEA then verifies
 * for itself.
 *
 * **Why hosted, and not the per-method API.** The V4 integration this replaces
 * tried to create a payment method server-side for each rail. That cannot work
 * for a card: Flutterwave requires the card number in the request, and WEA must
 * never hold one — a direct card charge would put the academy in PCI scope.
 * Hosted checkout is the arrangement where the card is entered on
 * Flutterwave's page, under Flutterwave's certificate, and WEA never sees it.
 *
 * **Nothing here concludes that anything was paid.** `verifyTransaction` asks
 * Flutterwave what happened and reports it; the decision to write `PAID` is
 * made in one place, after the amount and currency have been checked against
 * what was owed.
 */

import { num, str } from './http';

/**
 * An identifier that may arrive as a string or a number.
 *
 * Flutterwave sends the transaction id as a JSON number. `str` returns empty
 * for anything that is not a string, so reading it with that alone silently
 * dropped the one value the whole verification depends on — and a payment with
 * no id to verify by stays pending for ever.
 */
const idOf = (value: unknown): string =>
  typeof value === 'number' && Number.isFinite(value)
    ? String(value)
    : str(value);

/** One host for both test and live: the key decides which account is used. */
const V3_BASE_URL = 'https://api.flutterwave.com/v3';

export interface FlutterwaveV3Config {
  secretKey: string;
  /** `SANDBOX` or `PRODUCTION`, read from the key rather than configured. */
  environment: string;
  usable: boolean;
  reason: string;
}

export interface V3Secrets {
  FLW_SECRET_KEY?: string;
  /** The secret hash set on the Flutterwave dashboard's webhook page. */
  FLW_SECRET_HASH?: string;
  FLW_WEBHOOK_SECRET?: string;
}

/**
 * The configuration, and whether it can take a payment at all.
 *
 * The environment is derived from the key — Flutterwave's test keys are
 * prefixed `FLWSECK_TEST` — rather than set separately. That removes the
 * failure the V4 configuration had to guard against by hand: it is not
 * possible to point a live key at a sandbox setting, or a test key at
 * production, because there is only one setting and the key *is* it.
 */
export function resolveV3Config(secrets: V3Secrets): FlutterwaveV3Config {
  const secretKey = str(secrets.FLW_SECRET_KEY);
  const isTest = secretKey.toUpperCase().startsWith('FLWSECK_TEST');

  return {
    secretKey,
    environment: isTest ? 'SANDBOX' : 'PRODUCTION',
    usable: secretKey !== '',
    reason: secretKey === '' ? 'Not configured: FLW_SECRET_KEY unset.' : '',
  };
}

/** The webhook's shared secret, however it was named. */
export const webhookHash = (secrets: V3Secrets): string =>
  str(secrets.FLW_SECRET_HASH) || str(secrets.FLW_WEBHOOK_SECRET);

interface V3Response {
  ok: boolean;
  status: number;
  data: Record<string, unknown>;
  message: string;
}

async function call(
  config: FlutterwaveV3Config,
  method: string,
  path: string,
  body?: unknown,
): Promise<V3Response> {
  let response: Response;
  try {
    response = await fetch(`${V3_BASE_URL}${path}`, {
      method,
      headers: {
        Authorization: `Bearer ${config.secretKey}`,
        'Content-Type': 'application/json',
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch (error) {
    // A network failure is not a declined payment. Reported as such so nothing
    // upstream records a refusal that the processor never made.
    return {
      ok: false,
      status: 0,
      data: {},
      message: `Could not reach the payment processor (${String(error)}).`,
    };
  }

  const payload = (await response.json().catch(() => ({}))) as Record<string, unknown>;
  const message = str(payload.message);

  if (!response.ok || str(payload.status) === 'error') {
    return {
      ok: false,
      status: response.status,
      data: (payload.data as Record<string, unknown>) ?? {},
      message: message || `Flutterwave returned ${response.status}.`,
    };
  }
  return {
    ok: true,
    status: response.status,
    data: (payload.data as Record<string, unknown>) ?? {},
    message,
  };
}

/**
 * The methods offered on the checkout, in the order they appear.
 *
 * Card first, deliberately: it is the method most payers reach for, the only
 * one that works for every currency, and the one that completes without the
 * payer leaving the page.
 *
 * The rest are Nigerian rails and are only listed against a naira price —
 * offering a bank transfer for a dollar charge would fail after the payer had
 * committed to it. Flutterwave shows only what the account actually supports,
 * so this narrows the list rather than promising anything.
 */
export function paymentOptionsFor(currency: string): string {
  const code = str(currency).toUpperCase();
  if (code === 'NGN') return 'card, banktransfer, ussd, account, opay';
  return 'card';
}

export interface HostedCheckout {
  ok: boolean;
  link?: string;
  code?: string;
  message?: string;
}

export interface CheckoutRequest {
  reference: string;
  amount: number;
  currency: string;
  email: string;
  name: string;
  phone: string;
  description: string;
  returnUrl: string;
  logoUrl?: string;
}

/**
 * Creates the hosted checkout and returns the link to send the payer to.
 *
 * `tx_ref` is WEA's own reference, which is what ties the result back to a
 * registration. Flutterwave requires it to be unique, and the caller makes it
 * so by appending the moment the attempt was made — a payer who abandons a
 * checkout and starts again gets a new one rather than colliding.
 */
export async function createHostedCheckout(
  config: FlutterwaveV3Config,
  request: CheckoutRequest,
): Promise<HostedCheckout> {
  if (!config.usable) {
    return { ok: false, code: 'PAYMENT_NOT_CONFIGURED', message: config.reason };
  }

  const result = await call(config, 'POST', '/payments', {
    tx_ref: request.reference,
    // Sent as a string: Flutterwave documents the field as one, and a float
    // formatted by JSON is how rounding errors reach a receipt.
    amount: String(request.amount),
    currency: str(request.currency).toUpperCase() || 'NGN',
    redirect_url: request.returnUrl,
    payment_options: paymentOptionsFor(request.currency),
    customer: {
      email: request.email,
      name: request.name,
      phonenumber: request.phone,
    },
    customizations: {
      title: 'WUCO Executive Academy',
      description: request.description,
      ...(request.logoUrl ? { logo: request.logoUrl } : {}),
    },
    meta: { wea_reference: request.reference },
  });

  if (!result.ok) {
    console.error('Flutterwave v3 checkout failed', result.status, result.message);
    return {
      ok: false,
      code: 'PAYMENT_INITIALISATION_FAILED',
      message: result.message,
    };
  }

  const link = str(result.data.link);
  if (link === '') {
    return {
      ok: false,
      code: 'PAYMENT_INITIALISATION_FAILED',
      message: 'Flutterwave accepted the request but returned no checkout link.',
    };
  }
  return { ok: true, link };
}

export interface VerifiedTransaction {
  found: boolean;
  /** Flutterwave's own word: `successful`, `failed`, `cancelled`, `pending`. */
  status: string;
  transactionId: string;
  reference: string;
  amount: number;
  currency: string;
  raw: Record<string, unknown>;
}

/**
 * Asks Flutterwave what actually happened to a transaction.
 *
 * By transaction id, which is what both the redirect and the webhook carry.
 * There is deliberately no lookup by our own reference: it is not a documented
 * v3 endpoint, and a payment that cannot be confirmed must stay pending rather
 * than be resolved by guesswork.
 *
 * The caller still has to check the amount, the currency and the reference
 * before treating this as paid. A `successful` status alone says only that
 * *something* was paid.
 */
export async function verifyTransaction(
  config: FlutterwaveV3Config,
  transactionId: string,
): Promise<VerifiedTransaction> {
  const empty: VerifiedTransaction = {
    found: false,
    status: '',
    transactionId: '',
    reference: '',
    amount: 0,
    currency: '',
    raw: {},
  };
  if (!config.usable || str(transactionId) === '') return empty;

  const result = await call(
    config,
    'GET',
    `/transactions/${encodeURIComponent(str(transactionId))}/verify`,
  );
  if (!result.ok) return empty;

  return {
    found: true,
    status: str(result.data.status).toLowerCase(),
    transactionId: idOf(result.data.id) || str(transactionId),
    reference: str(result.data.tx_ref),
    amount: num(result.data.amount) ?? 0,
    currency: str(result.data.currency).toUpperCase(),
    raw: result.data,
  };
}

export interface V3WebhookEvent {
  ok: boolean;
  event: string;
  reference: string;
  transactionId: string;
}

/**
 * Reads a webhook, refusing anything that does not carry the shared secret.
 *
 * v3 authenticates webhooks with a plain header comparison rather than a
 * signature over the body, so the check is an equality — but it is still a
 * check, and a deployment with no secret configured refuses everything rather
 * than accepting anything. An unauthenticated webhook is a way to tell WEA
 * that an unpaid registration was paid.
 *
 * Compared without short-circuiting so the comparison itself leaks nothing
 * about how much of the secret was right.
 */
export function readV3Webhook(
  rawBody: string,
  headerHash: string,
  configuredHash: string,
): V3WebhookEvent {
  const refused: V3WebhookEvent = {
    ok: false,
    event: '',
    reference: '',
    transactionId: '',
  };
  if (configuredHash === '' || headerHash === '') return refused;
  if (!constantTimeEquals(headerHash, configuredHash)) return refused;

  let body: Record<string, unknown> = {};
  try {
    body = JSON.parse(rawBody) as Record<string, unknown>;
  } catch {
    return refused;
  }

  const data = (body.data as Record<string, unknown>) ?? {};
  return {
    ok: true,
    event: str(body.event),
    reference: str(data.tx_ref),
    transactionId: idOf(data.id),
  };
}

/** Equality that takes the same time whatever the inputs. */
function constantTimeEquals(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let difference = 0;
  for (let index = 0; index < a.length; index += 1) {
    difference |= a.charCodeAt(index) ^ b.charCodeAt(index);
  }
  return difference === 0;
}
