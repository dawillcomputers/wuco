/**
 * Payment processing, kept behind one interface.
 *
 * No provider is compiled into the rest of the application. A payment method
 * row names a provider; this module maps that name to an implementation, and
 * everything else — events, registrations, the CMS — deals only in
 * "initialise a payment" and "tell me whether it was actually paid".
 *
 * Two rules hold for every provider:
 *
 *   1. The amount is read from the database, never from the request. A client
 *      cannot ask to pay less than the event costs.
 *   2. `verify` is the only thing that may report PAID, and it asks the
 *      processor directly. A success callback arriving from a browser is
 *      treated as a hint that it is worth checking, and nothing more.
 */

import { str } from './http';

export type ProviderName = 'FLUTTERWAVE' | 'PAYSTACK' | 'MANUAL';

export type PaymentOutcome = 'PENDING' | 'PROCESSING' | 'PAID' | 'FAILED' | 'CANCELLED';

/** Secrets live in the Worker environment; they are never sent to a client. */
export interface PaymentSecrets {
  FLUTTERWAVE_SECRET_KEY?: string;
  FLUTTERWAVE_WEBHOOK_HASH?: string;
  PAYSTACK_SECRET_KEY?: string;
}

/** The configured method, as stored by the Super Admin. */
export interface PaymentMethodRow {
  id: string;
  title: string;
  kind: string;
  instructions: string;
  currency: string;
  reference_prefix: string;
  gateway_provider: string;
  gateway_checkout_url: string;
  gateway_public_key: string;
}

export interface InitialiseInput {
  reference: string;
  amount: number;
  currency: string;
  email: string;
  name: string;
  phone: string;
  description: string;
  /** Where the processor should send the payer once they are done. */
  returnUrl: string;
}

export interface InitialiseResult {
  ok: boolean;
  /** Absent for MANUAL, where there is nowhere to send the payer. */
  checkoutUrl?: string;
  transactionId?: string;
  /** Shown to the payer when there is no checkout to redirect to. */
  instructions?: string;
  code?: string;
  message?: string;
}

export interface VerifyResult {
  status: PaymentOutcome;
  transactionId?: string;
  amount?: number;
  currency?: string;
  reason?: string;
  /** Trimmed provider response kept for support. Never any card detail. */
  payload: Record<string, unknown>;
}

interface PaymentProvider {
  readonly name: ProviderName;
  /** False when the deployment has no key for it, so it is never offered. */
  isConfigured(secrets: PaymentSecrets): boolean;
  initialise(
    input: InitialiseInput,
    method: PaymentMethodRow,
    secrets: PaymentSecrets,
  ): Promise<InitialiseResult>;
  verify(
    reference: string,
    secrets: PaymentSecrets,
  ): Promise<VerifyResult>;
}

/** Reads a nested key without trusting any of the intermediate shapes. */
function dig(source: unknown, ...path: string[]): unknown {
  let value: unknown = source;
  for (const key of path) {
    if (typeof value !== 'object' || value === null) return undefined;
    value = (value as Record<string, unknown>)[key];
  }
  return value;
}

const asNumber = (value: unknown): number | undefined => {
  const parsed = typeof value === 'number' ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
};

// ---------------------------------------------------------------------------
// Paystack
// ---------------------------------------------------------------------------

/** Paystack works in the minor unit — kobo for NGN, cents for USD. */
const toMinorUnits = (amount: number) => Math.round(amount * 100);
const fromMinorUnits = (amount: number) => amount / 100;

const paystack: PaymentProvider = {
  name: 'PAYSTACK',

  isConfigured: (secrets) => str(secrets.PAYSTACK_SECRET_KEY) !== '',

  async initialise(input, _method, secrets) {
    const response = await fetch('https://api.paystack.co/transaction/initialize', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${secrets.PAYSTACK_SECRET_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        email: input.email,
        amount: toMinorUnits(input.amount),
        currency: input.currency,
        reference: input.reference,
        callback_url: input.returnUrl,
        metadata: { name: input.name, phone: input.phone, description: input.description },
      }),
    });
    const body = (await response.json().catch(() => ({}))) as Record<string, unknown>;
    const checkoutUrl = str(dig(body, 'data', 'authorization_url'));
    if (!response.ok || checkoutUrl === '') {
      return {
        ok: false,
        code: 'PAYMENT_INITIALISATION_FAILED',
        message: str(body.message) || 'The payment processor did not accept the request.',
      };
    }
    return {
      ok: true,
      checkoutUrl,
      transactionId: str(dig(body, 'data', 'reference')) || input.reference,
    };
  },

  async verify(reference, secrets) {
    const response = await fetch(
      `https://api.paystack.co/transaction/verify/${encodeURIComponent(reference)}`,
      { headers: { Authorization: `Bearer ${secrets.PAYSTACK_SECRET_KEY}` } },
    );
    const body = (await response.json().catch(() => ({}))) as Record<string, unknown>;
    if (!response.ok) {
      return {
        status: 'PROCESSING',
        reason: str(body.message) || 'Verification could not be completed.',
        payload: {},
      };
    }
    const state = str(dig(body, 'data', 'status')).toLowerCase();
    const minor = asNumber(dig(body, 'data', 'amount'));
    return {
      status:
        state === 'success'
          ? 'PAID'
          : state === 'failed' || state === 'reversed'
            ? 'FAILED'
            : state === 'abandoned'
              ? 'CANCELLED'
              : 'PROCESSING',
      transactionId: str(dig(body, 'data', 'id')) || reference,
      amount: minor === undefined ? undefined : fromMinorUnits(minor),
      currency: str(dig(body, 'data', 'currency')),
      reason: str(dig(body, 'data', 'gateway_response')),
      payload: {
        status: state,
        channel: str(dig(body, 'data', 'channel')),
        paid_at: str(dig(body, 'data', 'paid_at')),
      },
    };
  },
};

// ---------------------------------------------------------------------------
// Flutterwave
// ---------------------------------------------------------------------------

const flutterwave: PaymentProvider = {
  name: 'FLUTTERWAVE',

  isConfigured: (secrets) => str(secrets.FLUTTERWAVE_SECRET_KEY) !== '',

  async initialise(input, _method, secrets) {
    const response = await fetch('https://api.flutterwave.com/v3/payments', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${secrets.FLUTTERWAVE_SECRET_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        tx_ref: input.reference,
        amount: input.amount,
        currency: input.currency,
        redirect_url: input.returnUrl,
        customer: {
          email: input.email,
          name: input.name,
          phonenumber: input.phone,
        },
        customizations: { title: 'WUCO Executive Academy', description: input.description },
      }),
    });
    const body = (await response.json().catch(() => ({}))) as Record<string, unknown>;
    const checkoutUrl = str(dig(body, 'data', 'link'));
    if (!response.ok || checkoutUrl === '') {
      return {
        ok: false,
        code: 'PAYMENT_INITIALISATION_FAILED',
        message: str(body.message) || 'The payment processor did not accept the request.',
      };
    }
    return { ok: true, checkoutUrl };
  },

  async verify(reference, secrets) {
    const response = await fetch(
      `https://api.flutterwave.com/v3/transactions/verify_by_reference?tx_ref=${encodeURIComponent(reference)}`,
      { headers: { Authorization: `Bearer ${secrets.FLUTTERWAVE_SECRET_KEY}` } },
    );
    const body = (await response.json().catch(() => ({}))) as Record<string, unknown>;
    if (!response.ok) {
      // A transaction the processor has never heard of is one the payer never
      // started; anything else is worth asking about again.
      return {
        status: response.status === 404 ? 'PENDING' : 'PROCESSING',
        reason: str(body.message),
        payload: {},
      };
    }
    const state = str(dig(body, 'data', 'status')).toLowerCase();
    return {
      status:
        state === 'successful'
          ? 'PAID'
          : state === 'failed'
            ? 'FAILED'
            : state === 'cancelled'
              ? 'CANCELLED'
              : 'PROCESSING',
      transactionId: str(dig(body, 'data', 'id')),
      amount: asNumber(dig(body, 'data', 'amount')),
      currency: str(dig(body, 'data', 'currency')),
      reason: str(dig(body, 'data', 'processor_response')),
      payload: {
        status: state,
        payment_type: str(dig(body, 'data', 'payment_type')),
        created_at: str(dig(body, 'data', 'created_at')),
      },
    };
  },
};

// ---------------------------------------------------------------------------
// Manual — bank transfer, invoice, anything settled outside a processor
// ---------------------------------------------------------------------------

/**
 * There is nothing to call and nothing to verify automatically: the academy
 * confirms the payment when it lands. The registration still exists, still
 * carries a reference and still shows as pending until somebody says otherwise.
 */
const manual: PaymentProvider = {
  name: 'MANUAL',
  isConfigured: () => true,
  async initialise(_input, method) {
    return {
      ok: true,
      instructions:
        str(method.instructions) ||
        'Payment instructions will be sent to you by the academy office.',
    };
  },
  async verify() {
    return {
      status: 'PENDING',
      reason: 'Awaiting confirmation by the academy office.',
      payload: {},
    };
  },
};

const PROVIDERS: PaymentProvider[] = [paystack, flutterwave, manual];

/**
 * Which provider handles a configured method.
 *
 * A method is only treated as a gateway when it says so *and* the deployment
 * holds a key for it. An unconfigured gateway falls back to instructions
 * rather than sending the payer to a checkout that cannot work.
 */
export function providerFor(
  method: PaymentMethodRow | null,
  secrets: PaymentSecrets,
): PaymentProvider {
  if (!method || method.kind !== 'GATEWAY') return manual;
  const named = str(method.gateway_provider).toUpperCase();
  const provider = PROVIDERS.find((candidate) => candidate.name === named);
  if (!provider || !provider.isConfigured(secrets)) return manual;
  return provider;
}

export const providerNameFor = (
  method: PaymentMethodRow | null,
  secrets: PaymentSecrets,
): ProviderName => providerFor(method, secrets).name;

export const initialisePayment = (
  method: PaymentMethodRow | null,
  secrets: PaymentSecrets,
  input: InitialiseInput,
): Promise<InitialiseResult> => providerFor(method, secrets).initialise(input, method!, secrets);

export const verifyPayment = (
  provider: string,
  reference: string,
  secrets: PaymentSecrets,
): Promise<VerifyResult> => {
  const found = PROVIDERS.find((candidate) => candidate.name === provider) ?? manual;
  return found.verify(reference, secrets);
};

// ---------------------------------------------------------------------------
// Webhooks
// ---------------------------------------------------------------------------

const encoder = new TextEncoder();

async function hmacSha512Hex(secret: string, body: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-512' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign('HMAC', key, encoder.encode(body));
  return [...new Uint8Array(signature)]
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

function constantTimeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

export interface WebhookNotice {
  ok: boolean;
  provider: ProviderName;
  /** Our own reference, which is what the registration is found by. */
  reference: string;
}

/**
 * Authenticates a webhook and extracts the reference it concerns.
 *
 * Nothing in the body is believed beyond that reference: the caller re-verifies
 * against the processor's API before any money is considered received. A
 * forged webhook therefore achieves nothing but a wasted lookup.
 */
export async function readWebhook(
  provider: string,
  request: Request,
  rawBody: string,
  secrets: PaymentSecrets,
): Promise<WebhookNotice> {
  const name = provider.toUpperCase();
  let body: Record<string, unknown> = {};
  try {
    body = JSON.parse(rawBody) as Record<string, unknown>;
  } catch {
    return { ok: false, provider: 'MANUAL', reference: '' };
  }

  if (name === 'PAYSTACK') {
    const secret = str(secrets.PAYSTACK_SECRET_KEY);
    const signature = request.headers.get('x-paystack-signature') ?? '';
    if (secret === '' || !constantTimeEqual(signature, await hmacSha512Hex(secret, rawBody))) {
      return { ok: false, provider: 'PAYSTACK', reference: '' };
    }
    return {
      ok: true,
      provider: 'PAYSTACK',
      reference: str(dig(body, 'data', 'reference')),
    };
  }

  if (name === 'FLUTTERWAVE') {
    const expected = str(secrets.FLUTTERWAVE_WEBHOOK_HASH);
    const provided = request.headers.get('verif-hash') ?? '';
    if (expected === '' || !constantTimeEqual(provided, expected)) {
      return { ok: false, provider: 'FLUTTERWAVE', reference: '' };
    }
    return {
      ok: true,
      provider: 'FLUTTERWAVE',
      reference: str(dig(body, 'data', 'tx_ref')) || str(body.txRef),
    };
  }

  return { ok: false, provider: 'MANUAL', reference: '' };
}
