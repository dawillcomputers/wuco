/**
 * Flutterwave V4 (Next Gen).
 *
 * Everything that touches Flutterwave lives here. The rest of WEA asks the
 * payment abstraction in `payments.ts` to start or verify a payment and never
 * learns which processor answered.
 *
 * Safety properties this module is built around:
 *
 * **Nothing secret leaves the Worker.** The client id, client secret, webhook
 * secret and every access token stay server-side. The Flutter application is
 * given a redirect URL, or transfer instructions, and nothing else.
 *
 * **Sandbox unless told otherwise.** `FLW_ENVIRONMENT` defaults to `SANDBOX`,
 * and a production call cannot be made without both setting it to `PRODUCTION`
 * *and* supplying `FLW_V4_BASE_URL`. There is no compiled-in production host,
 * so a misconfigured deployment fails loudly rather than charging real cards.
 *
 * **No card data.** WEA never sees a card number, CVV or PIN. Card is handled
 * by redirecting the payer to Flutterwave; the direct-charge methods below
 * carry no sensitive detail at all.
 */

import { str } from './http';

export interface FlutterwaveConfig {
  /** `SANDBOX` (default) or `PRODUCTION`. */
  FLW_ENVIRONMENT?: string;
  /**
   * Base URL for V4 calls, without a trailing slash.
   *
   * Deliberately not defaulted for production: Flutterwave's published V4
   * specification documents only the sandbox host, so guessing the production
   * one would be inventing an endpoint.
   */
  FLW_V4_BASE_URL?: string;
  FLW_CLIENT_ID?: string;
  FLW_CLIENT_SECRET?: string;
  /** Shared secret used to sign webhooks. */
  FLW_WEBHOOK_SECRET?: string;
  /**
   * Encryption key, held for the card direct-charge flow.
   *
   * Nothing sends it today, and that is deliberate. It exists to encrypt card
   * data before it reaches Flutterwave, and WEA does not collect card data —
   * card goes through a redirect precisely so that it never has to. It is
   * configured here so the credential is in place if that flow is ever
   * adopted, and so it lives with the other secrets rather than in somebody's
   * notes.
   *
   * It is a secret: server-side only, never in a response, never in the app.
   */
  FLW_ENCRYPTION_KEY?: string;
}

/** The sandbox host, as published in Flutterwave's V4 specification. */
const SANDBOX_BASE_URL = 'https://developersandbox-api.flutterwave.com';

const TOKEN_URL =
  'https://idp.flutterwave.com/realms/flutterwave/protocol/openid-connect/token';

// ---------------------------------------------------------------------------
// Payment methods
// ---------------------------------------------------------------------------

/**
 * A method WEA can offer.
 *
 * `directCharge` means the payer chooses it in WEA and Flutterwave returns
 * instructions — a virtual account, a USSD string — with no sensitive data
 * involved. `redirect` means the payer is sent to Flutterwave to complete it,
 * which is how card is handled so that no card detail reaches WEA.
 */
export interface PaymentMethodOption {
  key: string;
  label: string;
  description: string;
  /** The `type` Flutterwave's V4 payment-methods endpoint expects. */
  providerType: string;
  flow: 'directCharge' | 'redirect';
  /**
   * Currencies this method can settle in, or empty for any.
   *
   * USSD, OPay and NQR are Nigerian rails: they cannot take dollars, and
   * offering them against a dollar price would fail at the processor after
   * the payer had committed.
   */
  currencies: string[];
}

export const FLUTTERWAVE_METHODS: PaymentMethodOption[] = [
  {
    key: 'bank_transfer',
    label: 'Bank Transfer',
    description: 'Transfer the exact amount from your banking app.',
    providerType: 'bank_transfer',
    currencies: ['NGN'],
    flow: 'directCharge',
  },
  {
    key: 'ussd',
    label: 'USSD',
    description: 'Dial a short code from the phone linked to your bank.',
    providerType: 'ussd',
    currencies: ['NGN'],
    flow: 'directCharge',
  },
  {
    key: 'opay',
    label: 'OPay',
    description: 'Authorise the payment from your OPay wallet.',
    providerType: 'opay',
    currencies: ['NGN'],
    flow: 'directCharge',
  },
  {
    key: 'nqr',
    label: 'NQR',
    description: 'Scan the NIBSS QR code with your banking app.',
    providerType: 'nqr',
    currencies: ['NGN'],
    flow: 'directCharge',
  },
  {
    key: 'card',
    label: 'Card',
    description: 'Visa, Mastercard, Verve and others, on Flutterwave.',
    providerType: 'card',
    currencies: [],
    // Redirect, never direct charge: a direct card charge would put WEA in
    // PCI scope by requiring the card number.
    flow: 'redirect',
  },
  {
    key: 'bank_account',
    label: 'Bank Account',
    description: 'Pay directly from your bank account.',
    providerType: 'bank_account',
    currencies: ['NGN'],
    flow: 'directCharge',
  },
];

export const methodByKey = (key: string): PaymentMethodOption | undefined =>
  FLUTTERWAVE_METHODS.find((method) => method.key === key);

// ---------------------------------------------------------------------------
// Shaping what WEA holds into what the processor accepts
// ---------------------------------------------------------------------------

/**
 * A name in the form the customer endpoint accepts.
 *
 * It permits letters, spaces, apostrophes and hyphens, between two and fifty
 * characters. A registrant may have typed anything, and a rejected customer
 * means a rejected payment, so anything outside that is dropped rather than
 * sent — a payment must not fail because somebody has a full stop in their
 * name.
 */
function customerName(first: string, last: string): Record<string, string> | undefined {
  const clean = (value: string) =>
    value
      .replace(/[^\p{L} '-]/gu, '')
      .replace(/\s+/g, ' ')
      .trim()
      .slice(0, 50);

  const name: Record<string, string> = {};
  if (clean(first).length >= 2) name.first = clean(first);
  if (clean(last).length >= 2) name.last = clean(last);
  return Object.keys(name).length > 0 ? name : undefined;
}

/**
 * A telephone number split into the country code and subscriber number the
 * customer endpoint requires, which wants seven to ten digits in `number`.
 *
 * Nigerian numbers are usually given as `08012345678` — eleven digits with a
 * trunk zero — which is one too many, so the zero is dropped and the country
 * code supplied separately. A number that cannot be read confidently is
 * omitted: the field is optional, and guessing at somebody's country would be
 * worse than leaving it out.
 */
function customerPhone(raw: string): Record<string, string> | undefined {
  const digits = raw.replace(/\D/g, '');

  // International, already carrying Nigeria's country code.
  if (digits.length === 13 && digits.startsWith('234')) {
    return { country_code: '234', number: digits.slice(3) };
  }
  // National, with the trunk zero.
  if (digits.length === 11 && digits.startsWith('0')) {
    return { country_code: '234', number: digits.slice(1) };
  }
  // Already the subscriber number alone.
  if (digits.length >= 7 && digits.length <= 10) {
    return { country_code: '234', number: digits };
  }
  return undefined;
}

// ---------------------------------------------------------------------------
// Configuration
// ---------------------------------------------------------------------------

export interface ResolvedConfig {
  environment: 'SANDBOX' | 'PRODUCTION';
  baseUrl: string;
  clientId: string;
  clientSecret: string;
  webhookSecret: string;
  /** Reserved for the card direct-charge flow. Never leaves the Worker. */
  encryptionKey: string;
  /** False when credentials are missing, in which case nothing is attempted. */
  usable: boolean;
  /** Why it is unusable, for the log. Never shown to a payer. */
  reason: string;
}

/**
 * Works out what this deployment is allowed to do.
 *
 * Production requires an explicitly configured base URL. That is the guard
 * against a half-configured deployment quietly talking to a live processor.
 */
export function resolveConfig(config: FlutterwaveConfig): ResolvedConfig {
  const environment =
    str(config.FLW_ENVIRONMENT).toUpperCase() === 'PRODUCTION'
      ? 'PRODUCTION'
      : 'SANDBOX';
  const configuredBase = str(config.FLW_V4_BASE_URL).replace(/\/$/, '');
  const clientId = str(config.FLW_CLIENT_ID);
  const clientSecret = str(config.FLW_CLIENT_SECRET);

  const baseUrl =
    environment === 'PRODUCTION' ? configuredBase : configuredBase || SANDBOX_BASE_URL;

  let reason = '';
  if (clientId === '' || clientSecret === '') {
    reason = 'FLW_CLIENT_ID and FLW_CLIENT_SECRET are not set.';
  } else if (baseUrl === '') {
    reason = 'FLW_ENVIRONMENT is PRODUCTION but FLW_V4_BASE_URL is not set.';
  }

  return {
    environment,
    baseUrl,
    clientId,
    clientSecret,
    webhookSecret: str(config.FLW_WEBHOOK_SECRET),
    encryptionKey: str(config.FLW_ENCRYPTION_KEY),
    usable: reason === '',
    reason,
  };
}

// ---------------------------------------------------------------------------
// OAuth
// ---------------------------------------------------------------------------

interface CachedToken {
  token: string;
  expiresAt: number;
  /** Cached per credential, so two environments cannot share a token. */
  fingerprint: string;
}

/**
 * Access tokens live ten minutes, so they are cached in the isolate and
 * refreshed a minute early. A Worker isolate is short-lived and there may be
 * many of them; this saves a round trip where it can and is simply a miss
 * where it cannot.
 */
let cached: CachedToken | null = null;

/** Exposed for tests, which must not inherit another case's token. */
export function resetTokenCache(): void {
  cached = null;
}

async function accessToken(config: ResolvedConfig): Promise<string | null> {
  const fingerprint = `${config.environment}:${config.clientId}`;
  if (cached && cached.fingerprint === fingerprint && cached.expiresAt > Date.now()) {
    return cached.token;
  }

  const response = await fetch(TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'client_credentials',
      client_id: config.clientId,
      client_secret: config.clientSecret,
    }),
  });
  if (!response.ok) {
    // The body names the problem — an unknown client, a bad secret — and
    // contains no credential of ours, so it is safe to log.
    const detail = await response.text().catch(() => '');
    console.error('Flutterwave token request failed', response.status, detail.slice(0, 300));
    return null;
  }

  const body = (await response.json().catch(() => ({}))) as {
    access_token?: string;
    expires_in?: number;
  };
  const token = str(body.access_token);
  if (token === '') return null;

  const lifetime = Number(body.expires_in ?? 600);
  cached = {
    token,
    fingerprint,
    // A minute of headroom, as Flutterwave's guidance recommends.
    expiresAt: Date.now() + Math.max(lifetime - 60, 30) * 1000,
  };
  return token;
}

// ---------------------------------------------------------------------------
// Requests
// ---------------------------------------------------------------------------

interface ApiResult {
  ok: boolean;
  status: number;
  data: Record<string, unknown>;
  message: string;
}

const traceId = () => `wea-${crypto.randomUUID()}`;

async function call(
  config: ResolvedConfig,
  method: 'GET' | 'POST',
  path: string,
  body?: Record<string, unknown>,
  idempotencyKey?: string,
): Promise<ApiResult> {
  const token = await accessToken(config);
  if (!token) {
    return { ok: false, status: 401, data: {}, message: 'Could not authenticate.' };
  }

  const headers: Record<string, string> = {
    Authorization: `Bearer ${token}`,
    'Content-Type': 'application/json',
    // Required by V4 on every call, and what support will ask for.
    'X-Trace-Id': traceId(),
  };
  // Makes a retried charge safe: the processor collapses the duplicate rather
  // than taking the money twice.
  if (idempotencyKey) headers['X-Idempotency-Key'] = idempotencyKey;

  let response: Response;
  try {
    response = await fetch(`${config.baseUrl}${path}`, {
      method,
      headers,
      body: body ? JSON.stringify(body) : undefined,
    });
  } catch (error) {
    return { ok: false, status: 0, data: {}, message: `${error}`.slice(0, 200) };
  }

  const payload = (await response.json().catch(() => ({}))) as Record<string, unknown>;
  // A v4 rejection puts the offending fields in `error.validation_errors`
  // rather than in `message`, so both are kept.
  const detail = response.ok
    ? ''
    : JSON.stringify(payload.error ?? payload).slice(0, 400);
  return {
    ok: response.ok,
    status: response.status,
    data: (payload.data as Record<string, unknown>) ?? {},
    message: str(payload.message) || detail,
  };
}

// ---------------------------------------------------------------------------
// The service
// ---------------------------------------------------------------------------

export interface PaymentRequest {
  /** WEA's own reference. Echoed back and used to find the registration. */
  reference: string;
  amount: number;
  currency: string;
  methodKey: string;
  email: string;
  firstName: string;
  lastName: string;
  phone: string;
  /** Where Flutterwave returns the payer. */
  returnUrl: string;
  /** Reused where WEA already knows this payer at the processor. */
  customerId?: string;
}

export interface PaymentInstruction {
  ok: boolean;
  code?: string;
  message?: string;
  /** Present for the redirect flow. */
  checkoutUrl?: string;
  /** Present for a direct charge: what the payer must do, verbatim. */
  nextAction?: Record<string, unknown>;
  orderId?: string;
  customerId?: string;
  /** The processor's status at the moment of creation. Never trusted as paid. */
  status?: string;
}

/**
 * Everything WEA does with Flutterwave, behind one object.
 *
 * Kept as a class so a second processor can be introduced by writing another
 * one with the same shape, rather than by editing the registration system.
 */
export class FlutterwavePaymentService {
  constructor(private readonly config: ResolvedConfig) {}

  static from(env: FlutterwaveConfig): FlutterwavePaymentService {
    return new FlutterwavePaymentService(resolveConfig(env));
  }

  /**
   * The methods a payer may use for this currency, whatever they are paying
   * for.
   *
   * Events and programmes ask the same question and deserve the same answer:
   * there is nothing per-item to enable, so there is nothing per-item to look
   * up either.
   */
  static offeredFor(
    env: FlutterwaveConfig,
    currency: string,
  ): PaymentMethodOption[] {
    return FlutterwavePaymentService.from(env).getPaymentMethods(currency);
  }

  get environment(): string {
    return this.config.environment;
  }

  get usable(): boolean {
    return this.config.usable;
  }

  get unusableReason(): string {
    return this.config.reason;
  }

  /**
   * Whether an encryption key is configured.
   *
   * A boolean, never the value: this is the most that any caller needs to
   * know, and returning the key itself would be the first step towards it
   * reaching a response.
   */
  get hasEncryptionKey(): boolean {
    return this.config.encryptionKey !== '';
  }

  /**
   * The methods a payer may use for this currency.
   *
   * Decided by the currency and by whether this deployment holds credentials
   * at all — not by an administrator ticking boxes per event. Requiring that
   * meant a new event silently offered nothing, and duplicated a decision the
   * Flutterwave account already holds.
   *
   * A method that cannot settle the currency is omitted rather than shown and
   * then failed on at the processor.
   */
  getPaymentMethods(currency: string): PaymentMethodOption[] {
    if (!this.config.usable) return [];
    const code = str(currency).toUpperCase() || 'NGN';
    return FLUTTERWAVE_METHODS.filter(
      (method) => method.currencies.length === 0 || method.currencies.includes(code),
    );
  }

  /** Finds or creates the payer at the processor. */
  /** Set when the last customer attempt failed, for the error shown upstream. */
  private lastCustomerError = '';

  private async ensureCustomer(request: PaymentRequest): Promise<string | null> {
    if (request.customerId) return request.customerId;

    const result = await call(
      this.config,
      'POST',
      '/customers',
      {
        // Only the address is required. Everything else is included when it
        // can be shaped into what the endpoint accepts, and omitted when it
        // cannot, so a payment never fails over an optional field.
        email: request.email,
        name: customerName(request.firstName, request.lastName),
        phone: customerPhone(request.phone),
      },
      `cus-${request.reference}`,
    );
    if (!result.ok) {
      // The processor's own wording names the offending field, which is the
      // only thing that makes a 400 actionable. It carries no credential.
      this.lastCustomerError = `${result.status}: ${result.message || 'no detail'}`;
      console.error('Flutterwave customer creation failed', this.lastCustomerError);
      return null;
    }
    return str(result.data.id) || null;
  }

  /**
   * Registers the chosen method against the customer.
   *
   * Only methods that carry no sensitive data reach this — card is a redirect,
   * so no card number is ever sent from WEA.
   */
  private async createPaymentMethod(
    customerId: string,
    method: PaymentMethodOption,
    request: PaymentRequest,
  ): Promise<string | null> {
    const result = await call(
      this.config,
      'POST',
      '/payment-methods',
      {
        type: method.providerType,
        customer_id: customerId,
      },
      `pmd-${request.reference}-${method.key}`,
    );
    if (!result.ok) {
      console.error(
        'Flutterwave payment method creation failed',
        method.providerType,
        result.status,
        result.message,
      );
      return null;
    }
    return str(result.data.id) || null;
  }

  /**
   * Starts a payment.
   *
   * Returns either somewhere to send the payer or instructions to show them.
   * It never reports that anything has been paid: that is `verifyPayment`'s
   * job, and only after asking the processor.
   */
  async createPaymentOrder(request: PaymentRequest): Promise<PaymentInstruction> {
    if (!this.config.usable) {
      return {
        ok: false,
        code: 'PAYMENT_NOT_CONFIGURED',
        message: this.config.reason,
      };
    }
    const method = methodByKey(request.methodKey);
    if (!method) return { ok: false, code: 'UNSUPPORTED_PAYMENT_METHOD' };

    const customerId = await this.ensureCustomer(request);
    if (!customerId) {
      return {
        ok: false,
        code: 'PAYMENT_INITIALISATION_FAILED',
        message: `Could not create the customer at the payment processor (${this.lastCustomerError}).`,
      };
    }

    const paymentMethodId = await this.createPaymentMethod(customerId, method, request);
    if (!paymentMethodId) {
      return {
        ok: false,
        code: 'PAYMENT_INITIALISATION_FAILED',
        message: `The processor did not accept the ${method.key} payment method.`,
      };
    }

    const result = await call(
      this.config,
      'POST',
      '/orders',
      {
        amount: request.amount,
        currency: request.currency,
        reference: request.reference,
        customer_id: customerId,
        payment_method_id: paymentMethodId,
        redirect_url: request.returnUrl,
        meta: { wea_reference: request.reference },
      },
      `ord-${request.reference}`,
    );

    if (!result.ok) {
      console.error('Flutterwave order creation failed', result.status, result.message);
      return {
        ok: false,
        code: 'PAYMENT_INITIALISATION_FAILED',
        message: result.message || 'The processor did not accept the order.',
      };
    }

    const nextAction = (result.data.next_action as Record<string, unknown>) ?? {};
    const redirect = (nextAction.redirect_url as Record<string, unknown>) ?? {};

    return {
      ok: true,
      orderId: str(result.data.id),
      customerId,
      status: str(result.data.status),
      checkoutUrl: str(redirect.url) || undefined,
      // Passed through untouched so the interface can render whatever the
      // method needs — a virtual account, a USSD string, a QR payload.
      nextAction,
    };
  }

  /**
   * Asks the processor what actually happened.
   *
   * The only source of truth about payment. Returns the processor's own view
   * of status, amount and currency so the caller can check them against what
   * was owed.
   */
  async verifyPayment(reference: string): Promise<{
    found: boolean;
    status: string;
    amount?: number;
    currency?: string;
    transactionId?: string;
    customerId?: string;
    raw: Record<string, unknown>;
  }> {
    if (!this.config.usable) {
      return { found: false, status: 'UNKNOWN', raw: {} };
    }

    // Orders are looked up by our own reference, which is what ties the
    // processor's record back to a WEA registration.
    const result = await call(
      this.config,
      'GET',
      `/orders?reference=${encodeURIComponent(reference)}`,
    );
    if (!result.ok) return { found: false, status: 'UNKNOWN', raw: {} };

    // A list endpoint may answer with an array; a lookup with an object.
    const payload = Array.isArray(result.data)
      ? ((result.data as unknown as Record<string, unknown>[])[0] ?? {})
      : result.data;
    if (Object.keys(payload).length === 0) {
      return { found: false, status: 'UNKNOWN', raw: {} };
    }

    return {
      found: true,
      status: str(payload.status).toLowerCase(),
      amount: typeof payload.amount === 'number' ? payload.amount : undefined,
      currency: str(payload.currency),
      transactionId: str(payload.id),
      customerId: str(payload.customer_id),
      raw: {
        status: str(payload.status),
        reference: str(payload.reference),
        created: str(payload.created_datetime),
      },
    };
  }
}

// ---------------------------------------------------------------------------
// Webhooks
// ---------------------------------------------------------------------------

const encoder = new TextEncoder();

/**
 * Checks a V4 webhook signature.
 *
 * V4 sends `flutterwave-signature`: an HMAC-SHA256 of the raw request body,
 * keyed with the webhook secret, base64 encoded. This is not the V3 scheme,
 * where a static hash was compared for equality — a V3 check would reject
 * every V4 delivery, and a V4 check would accept nothing forged.
 */
export async function verifyWebhookSignature(
  rawBody: string,
  signature: string,
  secret: string,
): Promise<boolean> {
  if (secret === '' || signature === '') return false;

  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const digest = await crypto.subtle.sign('HMAC', key, encoder.encode(rawBody));
  const expected = btoa(String.fromCharCode(...new Uint8Array(digest)));

  if (expected.length !== signature.length) return false;
  let diff = 0;
  for (let i = 0; i < expected.length; i++) {
    diff |= expected.charCodeAt(i) ^ signature.charCodeAt(i);
  }
  return diff === 0;
}

export interface WebhookEvent {
  ok: boolean;
  type: string;
  /** WEA's own reference, which is what the registration is found by. */
  reference: string;
}

/**
 * Authenticates a webhook and extracts only the reference it concerns.
 *
 * Nothing else in the body is believed: the caller re-verifies against the
 * API before any money is treated as received, so a forged delivery that
 * somehow passed the signature check would still achieve nothing.
 */
export async function readWebhookEvent(
  rawBody: string,
  signature: string,
  secret: string,
): Promise<WebhookEvent> {
  if (!(await verifyWebhookSignature(rawBody, signature, secret))) {
    return { ok: false, type: '', reference: '' };
  }

  let body: Record<string, unknown> = {};
  try {
    body = JSON.parse(rawBody) as Record<string, unknown>;
  } catch {
    return { ok: false, type: '', reference: '' };
  }

  const data = (body.data as Record<string, unknown>) ?? {};
  return {
    ok: true,
    type: str(body.type),
    reference: str(data.reference),
  };
}
