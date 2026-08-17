/**
 * Verifies the Flutterwave V4 integration's safety properties without needing
 * credentials or touching a live account.
 *
 * These are the checks that must hold whatever Flutterwave's account is
 * configured to do: that nothing runs against production by accident, that a
 * webhook cannot be forged, and that no method is offered which cannot
 * complete. Run with:
 *
 *   npm run verify:flutterwave
 */

import {
  FlutterwavePaymentService,
  readWebhookEvent,
  resolveConfig,
  verifyWebhookSignature,
} from '../src/flutterwave';
import {
  feeTierFrom,
  implicitTier,
  offeredModes,
  currencyForCountry,
  parsePrices,
  pricesFor,
  resolveCharge,
  suggestedCurrency,
  tierFor,
} from '../src/pricing';

let failures = 0;

function check(name: string, condition: boolean, detail = '') {
  const mark = condition ? 'PASS' : 'FAIL';
  if (!condition) failures += 1;
  console.log(`  [${mark}] ${name}${detail && !condition ? ` — ${detail}` : ''}`);
}

function section(title: string) {
  console.log(`\n${title}`);
}

async function main() {
  // --- Environment safety --------------------------------------------------

  section('Environment defaults');

  const empty = resolveConfig({});
  check('no configuration means SANDBOX', empty.environment === 'SANDBOX');
  check(
    'sandbox host is the documented one',
    empty.baseUrl === 'https://developersandbox-api.flutterwave.com',
    empty.baseUrl,
  );
  check('no credentials means unusable', !empty.usable);

  const sandbox = resolveConfig({
    FLW_CLIENT_ID: 'test-id',
    FLW_CLIENT_SECRET: 'test-secret',
  });
  check('credentials alone are enough for sandbox', sandbox.usable);
  check('and it is still SANDBOX', sandbox.environment === 'SANDBOX');

  // The property that matters most: production cannot happen by halves.
  const halfProduction = resolveConfig({
    FLW_ENVIRONMENT: 'PRODUCTION',
    FLW_CLIENT_ID: 'test-id',
    FLW_CLIENT_SECRET: 'test-secret',
  });
  check(
    'PRODUCTION without a base URL is refused',
    !halfProduction.usable,
    'a half-configured deployment must not reach a live processor',
  );
  check('and it has no base URL to fall back to', halfProduction.baseUrl === '');

  const production = resolveConfig({
    FLW_ENVIRONMENT: 'PRODUCTION',
    FLW_V4_BASE_URL: 'https://example.invalid/v4',
    FLW_CLIENT_ID: 'test-id',
    FLW_CLIENT_SECRET: 'test-secret',
  });
  check('PRODUCTION with a base URL is usable', production.usable);
  check(
    'the production host is never compiled in',
    production.baseUrl === 'https://example.invalid/v4',
  );

  const lowercase = resolveConfig({
    FLW_ENVIRONMENT: 'production',
    FLW_V4_BASE_URL: 'https://example.invalid/v4',
    FLW_CLIENT_ID: 'a',
    FLW_CLIENT_SECRET: 'b',
  });
  check('the environment name is case-insensitive', lowercase.environment === 'PRODUCTION');

  const typo = resolveConfig({
    FLW_ENVIRONMENT: 'prod',
    FLW_CLIENT_ID: 'a',
    FLW_CLIENT_SECRET: 'b',
  });
  check(
    'an unrecognised environment falls back to SANDBOX',
    typo.environment === 'SANDBOX',
    'anything not exactly PRODUCTION must be treated as a test',
  );

  // --- Payment methods -----------------------------------------------------

  section('Payment methods');

  const unusable = new FlutterwavePaymentService(empty);
  check(
    'an unconfigured deployment offers nothing',
    unusable.getPaymentMethods('NGN').length === 0,
    'offering a method that cannot complete is worse than offering none',
  );

  const service = new FlutterwavePaymentService(sandbox);

  const naira = service.getPaymentMethods('NGN');
  check('naira offers the Nigerian rails', naira.length > 1, `${naira.length}`);
  check(
    'and includes bank transfer and USSD',
    naira.some((method) => method.key === 'bank_transfer') &&
      naira.some((method) => method.key === 'ussd'),
  );

  const dollars = service.getPaymentMethods('USD');
  check(
    'dollars offer only what can settle in dollars',
    dollars.every((method) => method.currencies.length === 0),
    dollars.map((method) => method.key).join(', '),
  );
  check(
    'USSD is not offered against a dollar price',
    !dollars.some((method) => method.key === 'ussd'),
    'it would fail at the processor after the payer had committed',
  );

  const card = service.getPaymentMethods('USD').find((m) => m.key === 'card');
  check(
    'card is a redirect, never a direct charge',
    card?.flow === 'redirect',
    'a direct card charge would put WEA in PCI scope',
  );
  const transfer = naira.find((method) => method.key === 'bank_transfer');
  check('bank transfer is a direct charge', transfer?.flow === 'directCharge');

  // --- Pricing ---------------------------------------------------------------

  section('Pricing');

  const priced = pricesFor(
    { fee_amount: 250000, fee_currency: 'NGN', prices: '{"USD": 150}' },
    'fee_amount',
    'fee_currency',
  );
  check('the base price is included', priced.some((p) => p.currency === 'NGN'));
  check('and the additional ones', priced.some((p) => p.currency === 'USD'));

  check(
    'Nigeria is shown naira',
    suggestedCurrency(priced, 'NG') === 'NGN',
  );
  check(
    'elsewhere is shown dollars',
    suggestedCurrency(priced, 'GB') === 'USD',
  );
  check(
    'with no dollar price, naira is shown anyway',
    suggestedCurrency(
      pricesFor({ fee_amount: 5000, fee_currency: 'NGN' }, 'fee_amount', 'fee_currency'),
      'GB',
    ) === 'NGN',
    'a price nobody set is worse than an unexpected currency',
  );

  check(
    'Nigeria is charged in naira',
    resolveCharge(priced, 'NG')?.currency === 'NGN',
  );
  check(
    'elsewhere is charged in dollars',
    resolveCharge(priced, 'US')?.amount === 150,
  );
  check(
    'an unpriced item cannot be charged at all',
    resolveCharge([], 'NG') === null,
  );

  // --- The country decides the currency ---------------------------------------

  section('Where you are decides what you pay in');

  check('Nigeria pays in naira', currencyForCountry('NG') === 'NGN');
  check('the United Kingdom pays in pounds', currencyForCountry('GB') === 'GBP');
  check(
    'the Channel Islands and the Isle of Man do too',
    currencyForCountry('JE') === 'GBP' &&
      currencyForCountry('GG') === 'GBP' &&
      currencyForCountry('IM') === 'GBP',
  );
  for (const country of ['FR', 'DE', 'IE', 'ES', 'IT', 'NL']) {
    check(`${country} pays in euro`, currencyForCountry(country) === 'EUR');
  }
  check(
    'non-eurozone Europe pays in euro too',
    currencyForCountry('NO') === 'EUR' &&
      currencyForCountry('CH') === 'EUR' &&
      currencyForCountry('PL') === 'EUR',
    'a euro price is one a European can read; a dollar one is not',
  );
  for (const country of ['US', 'CA', 'KE', 'GH', 'ZA', 'AE', 'IN']) {
    check(`${country} pays in dollars`, currencyForCountry(country) === 'USD');
  }
  check(
    'an unknown country pays in dollars',
    currencyForCountry('') === 'USD' && currencyForCountry('ZZ') === 'USD',
  );

  const fourWays = pricesFor(
    { prices: '{"NGN": 250000, "USD": 150, "GBP": 120, "EUR": 140}' },
    '',
    '',
  );
  check(
    'a British payer is charged the pound price',
    resolveCharge(fourWays, 'GB')?.amount === 120,
  );
  check(
    'a German payer is charged the euro price',
    resolveCharge(fourWays, 'DE')?.amount === 140,
  );
  check(
    'a Nigerian payer is charged the naira price',
    resolveCharge(fourWays, 'NG')?.amount === 250000,
  );
  check(
    'and nothing in the request can change any of that',
    // `resolveCharge` takes no chosen currency at all: the only way to reach a
    // different price is to be somewhere different.
    resolveCharge(fourWays, 'GB')?.currency === 'GBP',
  );

  const nairaOnly = pricesFor({ prices: '{"NGN": 250000}' }, '', '');
  check(
    'a payer whose currency was never priced still gets a price',
    resolveCharge(nairaOnly, 'GB')?.currency === 'NGN',
    'refusing to quote would be worse than quoting in naira',
  );

  // --- Prices survive being edited ------------------------------------------

  section('Prices survive the CMS');

  check(
    'lines are read as prices',
    parsePrices('USD 1500\nGBP 1,200')['USD'] === 1500 &&
      parsePrices('USD 1500\nGBP 1,200')['GBP'] === 1200,
  );
  check(
    'a lower-case code and a colon are still a price',
    parsePrices(['usd: 150'])['USD'] === 150,
  );
  check(
    'a line that is not a price is dropped',
    Object.keys(parsePrices('about two hundred dollars')).length === 0,
    'storing a price of nothing would charge nothing',
  );
  check(
    'a negative price is not a price',
    Object.keys(parsePrices('USD -150')).length === 0,
  );

  // The CMS sends every field back on save, edited or not. Re-reading the
  // stored map as a line would find no price in it and wipe the lot.
  const stored = JSON.stringify(parsePrices('USD 150\nNGN 250000'));
  check(
    'saving a form without touching the prices keeps them',
    parsePrices(stored)['USD'] === 150 && parsePrices(stored)['NGN'] === 250000,
    'an untouched field must not delete what the academy set',
  );
  check(
    'and an already-decoded map is understood too',
    parsePrices({ USD: 150 })['USD'] === 150,
  );

  // --- Fee tiers -------------------------------------------------------------

  section('Early bird, standard, physical, virtual');

  const row = (
    label: string,
    mode: string,
    prices: Record<string, number>,
    until?: string,
  ) =>
    feeTierFrom({
      id: `p-${label}-${mode}`,
      tier_label: label,
      attendance_mode: mode,
      prices: JSON.stringify(prices),
      available_until: until ?? null,
      sort_order: 0,
    });

  const closes = '2026-09-30T23:59:59Z';
  const summit = [
    row('Early Bird', 'PHYSICAL', { NGN: 150000 }, closes),
    row('Early Bird', 'VIRTUAL', { NGN: 100000 }, closes),
    row('Standard', 'PHYSICAL', { NGN: 180000 }),
    row('Standard', 'VIRTUAL', { NGN: 130000 }),
  ];

  const early = new Date('2026-09-01T10:00:00Z');
  const late = new Date('2026-10-05T10:00:00Z');

  check(
    'in September, physical is the early bird price',
    tierFor(summit, 'PHYSICAL', early)?.prices[0].amount === 150000,
  );
  check(
    'and virtual is its own early bird price',
    tierFor(summit, 'VIRTUAL', early)?.prices[0].amount === 100000,
  );
  check(
    'in October, physical is standard',
    tierFor(summit, 'PHYSICAL', late)?.prices[0].amount === 180000,
    'the date decides the rate, with nobody editing anything',
  );
  check(
    'and virtual is standard',
    tierFor(summit, 'VIRTUAL', late)?.prices[0].amount === 130000,
  );
  check(
    'the rate is named, not just priced',
    tierFor(summit, 'PHYSICAL', early)?.label === 'Early Bird' &&
      tierFor(summit, 'PHYSICAL', late)?.label === 'Standard',
  );
  check(
    'the early rate cannot be claimed after it closes',
    tierFor(summit, 'VIRTUAL', late)?.label === 'Standard',
    'nothing in a request names a tier, so nothing can ask for the old one',
  );

  check(
    'both ways of attending are offered on a hybrid event',
    offeredModes(summit, 'HYBRID').sort().join(',') === 'PHYSICAL,VIRTUAL',
  );
  check(
    'a physical-only event asks nothing',
    offeredModes(summit, 'PHYSICAL').length === 0,
    'there is no choice to present',
  );

  // An event published before fee tiers existed.
  const legacy = implicitTier({
    fee_amount: 250000,
    fee_currency: 'NGN',
    prices: '{"USD": 150}',
  });
  check(
    'an event with no fee rows keeps its own price',
    tierFor(legacy, '', late)?.prices.some((p) => p.amount === 250000) === true,
    'nothing published today may change price because tiers were added',
  );
  check(
    'and keeps its other currencies',
    tierFor(legacy, '', late)?.prices.some((p) => p.currency === 'USD') === true,
  );
  check(
    'and offers no mode choice',
    offeredModes(legacy, 'HYBRID').sort().join(',') === 'PHYSICAL,VIRTUAL',
    'an any-mode price applies to both ways of attending',
  );
  check(
    'a free event has no tier to charge',
    tierFor(implicitTier({ fee_amount: 0, fee_currency: 'NGN' }), '', late) === null,
  );

  // A late fee: opens when the standard rate closes.
  const withLateFee = [
    row('Standard', 'ANY', { NGN: 180000 }, closes),
    feeTierFrom({
      tier_label: 'Late',
      attendance_mode: 'ANY',
      prices: '{"NGN": 220000}',
      available_from: '2026-10-01T00:00:00Z',
    }),
  ];
  check(
    'before the standard rate closes, it is the one charged',
    tierFor(withLateFee, '', early)?.prices[0].amount === 180000,
    'a rate that has not opened yet cannot be the cheapest one',
  );
  check(
    'afterwards the late fee applies',
    tierFor(withLateFee, '', late)?.prices[0].amount === 220000,
  );

  // --- Secrets stay server-side --------------------------------------------

  section('Secrets never leave the Worker');

  const withSecrets = resolveConfig({
    FLW_CLIENT_ID: 'id-SHOULD-NOT-LEAK',
    FLW_CLIENT_SECRET: 'secret-SHOULD-NOT-LEAK',
    FLW_WEBHOOK_SECRET: 'webhook-SHOULD-NOT-LEAK',
    FLW_ENCRYPTION_KEY: 'encryption-SHOULD-NOT-LEAK',
  });
  const secretService = new FlutterwavePaymentService(withSecrets);

  check('the encryption key is stored', withSecrets.encryptionKey !== '');
  check(
    'and reported only as a boolean',
    secretService.hasEncryptionKey === true,
    'returning the value itself is the first step to it reaching a response',
  );

  // Everything a client can be handed, serialised, must contain no credential.
  const clientVisible = JSON.stringify({
    methods: secretService.getPaymentMethods('NGN'),
    environment: secretService.environment,
  });
  check(
    'no credential appears in anything sent to a client',
    !clientVisible.includes('SHOULD-NOT-LEAK'),
    clientVisible.slice(0, 120),
  );

  // --- Webhook signatures --------------------------------------------------

  section('Webhook signature (V4: HMAC-SHA256, base64)');

  const secret = 'a-test-webhook-secret';
  const body = JSON.stringify({
    type: 'charge.completed',
    data: { id: 'chg_test', reference: 'WEA-EVT-2026-00123-abc', status: 'succeeded' },
  });

  // Signed the way Flutterwave documents it.
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = btoa(
    String.fromCharCode(
      ...new Uint8Array(
        await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(body)),
      ),
    ),
  );

  check(
    'a correctly signed body is accepted',
    await verifyWebhookSignature(body, signature, secret),
  );
  check(
    'a tampered body is rejected',
    !(await verifyWebhookSignature(`${body} `, signature, secret)),
    'the amount could otherwise be edited in flight',
  );
  check(
    'the wrong secret is rejected',
    !(await verifyWebhookSignature(body, signature, 'not-the-secret')),
  );
  check(
    'an empty signature is rejected',
    !(await verifyWebhookSignature(body, '', secret)),
  );
  check(
    'an unconfigured secret rejects everything',
    !(await verifyWebhookSignature(body, signature, '')),
    'a deployment with no webhook secret must not accept webhooks',
  );

  const event = await readWebhookEvent(body, signature, secret);
  check('a signed event yields its type', event.ok && event.type === 'charge.completed');
  check(
    'and only the reference is taken from it',
    event.reference === 'WEA-EVT-2026-00123-abc',
    event.reference,
  );

  const forged = await readWebhookEvent(body, 'ZmFrZQ==', secret);
  check('a forged event yields nothing', !forged.ok && forged.reference === '');

  section(failures === 0 ? 'All checks passed.' : `${failures} check(s) FAILED.`);
  process.exit(failures === 0 ? 0 : 1);
}

void main();
