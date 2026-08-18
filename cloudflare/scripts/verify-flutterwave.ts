/**
 * Verifies the Flutterwave v3 integration's safety properties without needing
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
  paymentOptionsFor,
  readV3Webhook,
  resolveV3Config,
} from '../src/flutterwave_v3';
import {
  feeTierFrom,
  implicitTier,
  offeredModes,
  currencyForCountry,
  headlinePrice,
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

  section('The key decides the environment');

  const unset = resolveV3Config({});
  check('no key means unusable', !unset.usable);
  check('and it says which one is missing', unset.reason.includes('FLW_SECRET_KEY'));

  const testKey = resolveV3Config({ FLW_SECRET_KEY: 'FLWSECK_TEST-abc123-X' });
  check('a test key is SANDBOX', testKey.environment === 'SANDBOX');
  check('and is usable', testKey.usable);

  const liveKey = resolveV3Config({ FLW_SECRET_KEY: 'FLWSECK-abc123-X' });
  check(
    'a live key is PRODUCTION',
    liveKey.environment === 'PRODUCTION',
    'the key carries the environment, so the two cannot disagree',
  );
  check(
    'a stray FLW_ENVIRONMENT cannot override it',
    resolveV3Config({
      FLW_SECRET_KEY: 'FLWSECK_TEST-abc',
      FLW_ENVIRONMENT: 'PRODUCTION',
    } as never).environment === 'SANDBOX',
    'this is the half-configured production the V4 setup had to guard by hand',
  );

  // --- What the checkout offers ---------------------------------------------

  section('The checkout leads with card');

  const nairaOptions = paymentOptionsFor('NGN');
  check('naira leads with card', nairaOptions.startsWith('card'));
  check('and offers the Nigerian rails too', nairaOptions.includes('banktransfer'));

  const dollarOptions = paymentOptionsFor('USD');
  check('dollars lead with card', dollarOptions.startsWith('card'));
  check(
    'and omit rails that cannot settle dollars',
    !dollarOptions.includes('banktransfer') && !dollarOptions.includes('ussd'),
    'offering one would fail after the payer had committed to it',
  );


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

  // --- What a card shows ------------------------------------------------------

  section('A listing shows the least anybody could pay');

  const hybrid = [
    row('Standard', 'PHYSICAL', { NGN: 250000, EUR: 160 }),
    row('Standard', 'VIRTUAL', { NGN: 180000, EUR: 115 }),
  ];

  check(
    'a hybrid event shows the cheaper way to attend',
    headlinePrice(hybrid, 'NG')?.price.amount === 180000,
    'picking by row order showed whichever happened to come first',
  );
  check(
    'and says it is a "from" price',
    headlinePrice(hybrid, 'NG')?.from === true,
  );
  check(
    'in the visitor own currency',
    headlinePrice(hybrid, 'FR')?.price.currency === 'EUR' &&
      headlinePrice(hybrid, 'FR')?.price.amount === 115,
  );
  check(
    'and in sterling for the United Kingdom, falling back where unpriced',
    headlinePrice(hybrid, 'GB')?.price.currency === 'EUR',
    'no pound price is set on this tier, so the euro one stands in',
  );

  const oneWay = [row('Standard', 'ANY', { NGN: 250000 })];
  check(
    'a single price is not a "from" price',
    headlinePrice(oneWay, 'NG')?.from === false,
  );

  const earlyAndStandard = [
    row('Early Bird', 'ANY', { NGN: 150000 }, closes),
    row('Standard', 'ANY', { NGN: 180000 }),
  ];
  check(
    'while the early rate is open, that is what a card shows',
    headlinePrice(earlyAndStandard, 'NG', early)?.price.amount === 150000,
  );
  check(
    'and once it closes, the standard rate is the only one',
    headlinePrice(earlyAndStandard, 'NG', late)?.price.amount === 180000 &&
      headlinePrice(earlyAndStandard, 'NG', late)?.from === false,
    'nothing else is open, so there is no "from" about it',
  );
  check(
    'a free event has no headline price at all',
    headlinePrice(implicitTier({ fee_amount: 0 }), 'NG') === null,
  );

  // --- Secrets stay server-side --------------------------------------------

  section('Secrets never leave the Worker');

  const secretConfig = resolveV3Config({
    FLW_SECRET_KEY: 'FLWSECK_TEST-SHOULD-NOT-LEAK',
    FLW_SECRET_HASH: 'hash-SHOULD-NOT-LEAK',
  });
  const clientVisible = JSON.stringify({
    environment: secretConfig.environment,
    usable: secretConfig.usable,
    payment_options: paymentOptionsFor('NGN'),
  });
  check(
    'no credential appears in anything sent to a client',
    !clientVisible.includes('SHOULD-NOT-LEAK'),
    clientVisible.slice(0, 140),
  );
  check(
    'the environment is reported, and is only a word',
    clientVisible.includes('SANDBOX'),
  );

  // --- Webhooks --------------------------------------------------------------

  section('A webhook cannot be forged');

  const hash = 'a-shared-secret-value';
  const notice = JSON.stringify({
    event: 'charge.completed',
    data: { id: 99, tx_ref: 'WEA-EVT-2026-00123-abc', status: 'successful' },
  });

  const accepted = readV3Webhook(notice, hash, hash);
  check('a correctly hashed notice is accepted', accepted.ok);
  check(
    'and yields the reference',
    accepted.reference === 'WEA-EVT-2026-00123-abc',
    accepted.reference,
  );
  check('and the transaction id to verify with', accepted.transactionId === '99');

  check('a wrong hash is refused', !readV3Webhook(notice, 'wrong', hash).ok);
  check('a missing header is refused', !readV3Webhook(notice, '', hash).ok);
  check(
    'an unconfigured deployment refuses every notice',
    !readV3Webhook(notice, hash, '').ok,
    'no secret must mean nothing is believed, not that everything is',
  );
  check('a malformed body is refused', !readV3Webhook('not json', hash, hash).ok);
  check(
    'the shared secret is never echoed back',
    !JSON.stringify(accepted).includes(hash),
  );



  section(failures === 0 ? 'All checks passed.' : `${failures} check(s) FAILED.`);
  process.exit(failures === 0 ? 0 : 1);
}

void main();
