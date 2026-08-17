/**
 * Programme tuition, through the same processor and the same rules as events.
 *
 * Events could already be paid for online; programmes could not, so tuition
 * arrived by transfer and somebody in the office marked it received. Both now
 * run on one set of credentials and one verification path, so there is a
 * single place where WEA decides money has arrived rather than two that could
 * disagree.
 *
 * As everywhere else: the amount comes from the database, and only
 * `settleTuitionPayment` may conclude that something was paid.
 */

import { newId } from './auth';
import { FlutterwavePaymentService } from './flutterwave';
import { num, str } from './http';
import { pricesFor, resolveCharge } from './pricing';
import {
  PaymentSecrets,
  initialisePayment,
  providerNameFor,
  verifyPayment,
} from './payments';
import { enrolFromRegistration } from './registrations';

export interface TuitionResult {
  ok: boolean;
  code?: string;
  message?: string;
  data?: Record<string, unknown>;
}

/**
 * Starts a tuition payment.
 *
 * The amount comes from the prices the academy set on the programme — never
 * from the request. All the request may do is name which of those prices to
 * charge, and a currency WEA never priced is refused rather than converted
 * into.
 */
export async function beginTuitionPayment(
  db: D1Database,
  registration: Record<string, unknown>,
  secrets: PaymentSecrets,
  returnUrl: string,
  methodKey?: string,
  country = '',
): Promise<TuitionResult> {
  const already = str(registration.status);
  if (already === 'PAID' || already === 'CONFIRMED') {
    return { ok: false, code: 'ALREADY_PAID' };
  }

  // Charged from the prices the academy set, in the currency the payer chose.
  // A currency WEA never priced is refused rather than converted into.
  const programme = await db
    .prepare(
      'SELECT tuition_amount, tuition_currency, prices FROM programmes WHERE id = ?1',
    )
    .bind(registration.programme_id)
    .first<Record<string, unknown>>();
  const charge = resolveCharge(
    pricesFor(programme ?? {}, 'tuition_amount', 'tuition_currency'),
    country,
  );
  if (!charge) return { ok: false, code: 'PAYMENT_NOT_REQUIRED' };
  const amount = charge.amount;

  if (str(methodKey) !== '') {
    const offered = FlutterwavePaymentService.offeredFor(
      secrets,
      charge.currency,
    );
    if (!offered.some((option) => option.key === methodKey)) {
      return { ok: false, code: 'UNSUPPORTED_PAYMENT_METHOD' };
    }
  }

  const applicant = await db
    .prepare('SELECT first_name, last_name, email, phone FROM users WHERE id = ?1')
    .bind(registration.user_id)
    .first<{
      first_name: string;
      last_name: string;
      email: string;
      phone: string | null;
    }>();
  if (!applicant) return { ok: false, code: 'NOT_FOUND' };

  const reference = `${str(registration.reference)}-${Date.now().toString(36)}`;
  const result = await initialisePayment(null, secrets, {
    reference,
    amount,
    currency: charge.currency,
    email: applicant.email,
    name: `${applicant.first_name} ${applicant.last_name}`.trim(),
    phone: str(applicant.phone),
    description: `WEA tuition ${str(registration.reference)}`,
    returnUrl,
    methodKey: str(methodKey) || undefined,
    customerId: str(registration.provider_customer_id) || undefined,
  });

  if (!result.ok) {
    return {
      ok: false,
      code: result.code ?? 'PAYMENT_INITIALISATION_FAILED',
      message: result.message,
    };
  }

  await db
    .prepare(
      `INSERT INTO programme_payments
         (id, registration_id, programme_id, provider, provider_reference,
          provider_transaction_id, checkout_url, amount, currency, status,
          payment_method_key, next_action)
       VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12)`,
    )
    .bind(
      `progpay-${newId()}`,
      registration.id,
      registration.programme_id,
      providerNameFor(null, secrets, str(methodKey)),
      reference,
      result.transactionId ?? null,
      result.checkoutUrl ?? null,
      amount,
      charge.currency,
      result.checkoutUrl ? 'PROCESSING' : 'PENDING',
      str(methodKey),
      JSON.stringify(result.nextAction ?? {}),
    )
    .run();

  if (result.customerId) {
    await db
      .prepare('UPDATE registrations SET provider_customer_id = ?1 WHERE id = ?2')
      .bind(result.customerId, registration.id)
      .run();
  }

  // What the applicant is actually being charged, so a receipt and a refund
  // quote the figure that was paid rather than the base price of a payment
  // made in another currency.
  await db
    .prepare(
      `UPDATE registrations
          SET amount = ?1, currency = ?2, chosen_currency = ?2,
              updated_at = CURRENT_TIMESTAMP
        WHERE id = ?3`,
    )
    .bind(amount, charge.currency, registration.id)
    .run();

  return {
    ok: true,
    data: {
      payment_reference: reference,
      checkout_url: result.checkoutUrl ?? null,
      next_action: result.nextAction ?? {},
      payment_method: str(methodKey),
      amount,
      currency: charge.currency,
    },
  };
}

/**
 * Asks the processor what happened, and enrols on success.
 *
 * Amount and currency are checked against what was owed before anything is
 * treated as paid: a payment for the wrong amount is not a payment, it is
 * something for the office to look at. On success the applicant is enrolled at
 * once — paying for a place is taking it up — and that step is idempotent, so
 * a webhook and a return redirect arriving for the same payment enrol once.
 */
export async function settleTuitionPayment(
  db: D1Database,
  paymentReference: string,
  secrets: PaymentSecrets,
): Promise<TuitionResult> {
  const payment = await db
    .prepare('SELECT * FROM programme_payments WHERE provider_reference = ?1')
    .bind(paymentReference)
    .first<Record<string, unknown>>();
  if (!payment) return { ok: false, code: 'NOT_FOUND' };

  if (str(payment.status) === 'PAID') {
    return {
      ok: true,
      data: { status: 'PAID', already_settled: true, payment_reference: paymentReference },
    };
  }

  const verification = await verifyPayment(
    str(payment.provider),
    paymentReference,
    secrets,
  );

  const expected = num(payment.amount) ?? 0;
  const expectedCurrency = str(payment.currency).toUpperCase();
  let outcome = verification.status;
  let reason = verification.reason ?? '';

  if (outcome === 'PAID') {
    const paid = verification.amount ?? 0;
    const paidCurrency = (verification.currency ?? '').toUpperCase();
    // A tolerance of one minor unit absorbs the processor's own rounding.
    if (paid + 0.01 < expected) {
      outcome = 'FAILED';
      reason = `Underpaid: ${paid} ${paidCurrency} against ${expected} ${expectedCurrency}.`;
    } else if (paidCurrency !== '' && paidCurrency !== expectedCurrency) {
      outcome = 'FAILED';
      reason = `Wrong currency: ${paidCurrency} against ${expectedCurrency}.`;
    }
  }

  await db
    .prepare(
      `UPDATE programme_payments
          SET status = ?1, failure_reason = ?2, provider_transaction_id = ?3,
              provider_payload = ?4,
              verified_at = CASE WHEN ?1 = 'PAID' THEN CURRENT_TIMESTAMP ELSE verified_at END,
              updated_at = CURRENT_TIMESTAMP
        WHERE id = ?5`,
    )
    .bind(
      outcome,
      reason,
      verification.transactionId ?? payment.provider_transaction_id ?? null,
      JSON.stringify(verification.payload),
      payment.id,
    )
    .run();

  const registration = await db
    .prepare('SELECT * FROM registrations WHERE id = ?1')
    .bind(payment.registration_id)
    .first<Record<string, unknown>>();
  if (!registration) return { ok: false, code: 'NOT_FOUND' };

  const status =
    outcome === 'PAID'
      ? 'PAID'
      : outcome === 'FAILED'
        ? 'AWAITING_PAYMENT'
        : str(registration.status);

  await db
    .prepare('UPDATE registrations SET status = ?1, updated_at = CURRENT_TIMESTAMP WHERE id = ?2')
    .bind(status, registration.id)
    .run();

  if (outcome === 'PAID') {
    await enrolFromRegistration(
      db,
      {
        user_id: str(registration.user_id),
        programme_id: str(registration.programme_id),
      },
      // Nobody decided; the payment did.
      null,
    );
  }

  return {
    ok: true,
    data: {
      status: outcome,
      registration_status: status,
      reason,
      payment_reference: paymentReference,
      enrolled: outcome === 'PAID',
    },
  };
}

/** The most recent tuition attempt, for the retry path. */
export async function latestTuitionPayment(
  db: D1Database,
  registrationId: string,
) {
  return db
    .prepare(
      `SELECT provider, provider_reference, checkout_url, next_action, status,
              failure_reason, amount, currency, payment_method_key, created_at
         FROM programme_payments WHERE registration_id = ?1
        ORDER BY created_at DESC LIMIT 1`,
    )
    .bind(registrationId)
    .first();
}
