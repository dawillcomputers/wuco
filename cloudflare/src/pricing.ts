/**
 * What something costs, in each currency the academy sells it in.
 *
 * **WEA never converts.** An exchange rate we invented would be stale by the
 * time somebody paid against it, and a payer would be charged a number nobody
 * at the academy ever chose. Each price is set deliberately; a currency with
 * no price set is simply not offered.
 *
 * Which currency a visitor is *shown* follows from where they are — naira in
 * Nigeria, dollars elsewhere — but that is only a default. The payer chooses,
 * and what they choose has to be a price the academy actually set.
 */

import { num, parseJson, str } from './http';

/** A price the academy has set. */
export interface Price {
  currency: string;
  amount: number;
}

/** The default outside Nigeria, where a naira price would mean little. */
const INTERNATIONAL_CURRENCY = 'USD';
const HOME_CURRENCY = 'NGN';
const HOME_COUNTRY = 'NG';

/**
 * Every price set for a row, base price included.
 *
 * The base `amount`/`currency` columns are folded in so nothing published
 * before multi-currency pricing loses its price or has to be re-entered.
 */
export function pricesFor(
  row: Record<string, unknown>,
  baseAmountColumn: string,
  baseCurrencyColumn: string,
): Price[] {
  const prices = new Map<string, number>();

  const base = num(row[baseAmountColumn]) ?? 0;
  const baseCurrency = str(row[baseCurrencyColumn]).toUpperCase();
  if (base > 0 && baseCurrency !== '') prices.set(baseCurrency, base);

  const extra = parseJson<Record<string, unknown>>(row.prices, {});
  for (const [currency, amount] of Object.entries(extra)) {
    const value = num(amount) ?? 0;
    const code = currency.trim().toUpperCase();
    if (value > 0 && code !== '') prices.set(code, value);
  }

  return [...prices.entries()].map(([currency, amount]) => ({ currency, amount }));
}

/**
 * The currency to show this visitor first.
 *
 * Naira in Nigeria, dollars outside it — falling back to whatever the academy
 * did set, because showing a price in a currency nobody priced would be worse
 * than showing an unexpected one.
 */
export function suggestedCurrency(prices: Price[], country: string): string {
  if (prices.length === 0) return HOME_CURRENCY;

  const wanted =
    str(country).toUpperCase() === HOME_COUNTRY
      ? HOME_CURRENCY
      : INTERNATIONAL_CURRENCY;

  const available = prices.map((price) => price.currency);
  if (available.includes(wanted)) return wanted;
  // Outside Nigeria with no dollar price, naira is better than nothing.
  if (available.includes(HOME_CURRENCY)) return HOME_CURRENCY;
  return available[0];
}

/** The country Cloudflare saw the request come from, or empty. */
export const countryOf = (request: Request): string =>
  (request as Request & { cf?: { country?: string } }).cf?.country ?? '';

/**
 * The price for a currency, or null when the academy never set one.
 *
 * Returning null rather than converting is the point: a currency WEA has no
 * price for is a currency WEA does not sell in.
 */
export function priceIn(prices: Price[], currency: string): Price | null {
  const code = str(currency).toUpperCase();
  return prices.find((price) => price.currency === code) ?? null;
}

/**
 * Resolves what a payer will actually be charged.
 *
 * The chosen currency has to be one of the set prices; anything else falls
 * back to the suggestion rather than being honoured, so a request cannot name
 * a currency — or an amount — the academy did not choose.
 */
export function resolveCharge(
  prices: Price[],
  chosenCurrency: string,
  country: string,
): Price | null {
  if (prices.length === 0) return null;
  return (
    priceIn(prices, chosenCurrency) ??
    priceIn(prices, suggestedCurrency(prices, country))
  );
}

/** Prices as the client should render them. */
export const pricesToJson = (prices: Price[]) =>
  prices.map((price) => ({ currency: price.currency, amount: price.amount }));

/**
 * Prices on their way into the database, from however they were submitted.
 *
 * The CMS edits them as `USD 1500` lines, because a currency map is an awkward
 * thing to type — but it also sends back the stored map untouched when a form
 * was saved without anybody editing this field. Reading that map as a line
 * would find no price in it and wipe every price the academy had set, so both
 * shapes are understood here rather than only the one a careful editor
 * produces.
 *
 * A line that is not a currency and an amount is dropped rather than stored as
 * a price of nothing.
 */
export function parsePrices(raw: unknown): Record<string, number> {
  const prices: Record<string, number> = {};
  const add = (currency: unknown, amount: unknown) => {
    const code = str(currency).toUpperCase();
    const value = num(amount) ?? 0;
    if (/^[A-Z]{3}$/.test(code) && value > 0) prices[code] = value;
  };

  const stored = asPriceMap(raw);
  if (stored) {
    for (const [currency, amount] of Object.entries(stored)) add(currency, amount);
    return prices;
  }

  const lines = Array.isArray(raw) ? raw : String(raw ?? '').split('\n');
  for (const line of lines) {
    // "USD 1500", "USD: 1,500" and "usd 1500.50" all name the same price.
    const match = String(line).trim().match(/^([A-Za-z]{3})[\s:]+([\d.,]+)$/);
    if (match) add(match[1], match[2].replace(/,/g, ''));
  }
  return prices;
}

/** The value as an already-encoded currency map, or null when it is not one. */
function asPriceMap(raw: unknown): Record<string, unknown> | null {
  if (typeof raw === 'object' && raw !== null && !Array.isArray(raw)) {
    return raw as Record<string, unknown>;
  }
  if (typeof raw === 'string' && raw.trim().startsWith('{')) {
    return parseJson<Record<string, unknown> | null>(raw, null);
  }
  return null;
}

// ---------------------------------------------------------------------------
// Fee tiers
// ---------------------------------------------------------------------------

/**
 * How a registrant is attending.
 *
 * `ANY` is a fee that applies whichever way they attend — which is every fee
 * on an event that has only one way.
 */
export type AttendanceMode = 'ANY' | 'PHYSICAL' | 'VIRTUAL';

/** One row of the fee table: a tier, for a mode, available in a window. */
export interface FeeTier {
  id: string;
  label: string;
  mode: AttendanceMode;
  prices: Price[];
  availableFrom: string;
  availableUntil: string;
  sortOrder: number;
}

/** A tier row as it comes out of the database. */
export function feeTierFrom(row: Record<string, unknown>): FeeTier {
  return {
    id: str(row.id),
    label: str(row.tier_label) || 'Standard',
    mode: (str(row.attendance_mode).toUpperCase() || 'ANY') as AttendanceMode,
    // A tier has no base column of its own: its whole price is the currency
    // map, read through the same parser the CMS writes with.
    prices: Object.entries(parsePrices(row.prices)).map(([currency, amount]) => ({
      currency,
      amount,
    })),
    availableFrom: str(row.available_from),
    availableUntil: str(row.available_until),
    sortOrder: num(row.sort_order) ?? 0,
  };
}

/**
 * The single implicit tier of an event that has no fee rows.
 *
 * Every event published before fee tiers existed is one of these, and goes on
 * charging exactly what it charged before. Treating "no rows" as "one unnamed
 * tier, any mode, always available" is what lets the rest of this module have
 * one code path rather than a legacy branch at every call site.
 */
export function implicitTier(event: Record<string, unknown>): FeeTier[] {
  const prices = pricesFor(event, 'fee_amount', 'fee_currency');
  if (prices.length === 0) return [];
  return [
    {
      id: '',
      label: '',
      mode: 'ANY',
      prices,
      availableFrom: '',
      availableUntil: '',
      sortOrder: 0,
    },
  ];
}

/** Whether a mode a registrant asked for is one this tier is sold in. */
const modeMatches = (tier: FeeTier, mode: string) => {
  const wanted = str(mode).toUpperCase();
  return tier.mode === 'ANY' || wanted === '' || tier.mode === wanted;
};

/** Whether `at` falls inside the tier's availability window. */
export function tierIsOpen(tier: FeeTier, at: Date): boolean {
  const now = at.getTime();
  if (tier.availableFrom !== '') {
    const from = Date.parse(tier.availableFrom);
    if (Number.isFinite(from) && now < from) return false;
  }
  if (tier.availableUntil !== '') {
    const until = Date.parse(tier.availableUntil);
    if (Number.isFinite(until) && now > until) return false;
  }
  return true;
}

/**
 * The tier a registrant gets, for how they are attending and when they asked.
 *
 * **The date decides, not the registrant.** Nothing in the request names a
 * tier, so nothing in the request can claim the early rate after it has
 * closed.
 *
 * Where more than one tier is open at once — Early Bird until the 30th
 * alongside a Standard rate with no end date — the one that *closes soonest*
 * wins, then the administrator's own ordering. A bounded offer beating an
 * open-ended one is what makes "Early Bird" mean early bird: it applies while
 * it lasts, and the moment it lapses the fallback takes over without anybody
 * editing anything. It also keeps a late fee working, since before its start
 * date it is simply not open.
 */
export function tierFor(
  tiers: FeeTier[],
  mode: string,
  at: Date = new Date(),
): FeeTier | null {
  const open = tiers
    .filter((tier) => modeMatches(tier, mode) && tierIsOpen(tier, at))
    .sort((a, b) => {
      const aEnds = a.availableUntil === '' ? Infinity : Date.parse(a.availableUntil);
      const bEnds = b.availableUntil === '' ? Infinity : Date.parse(b.availableUntil);
      if (aEnds !== bEnds) return aEnds - bEnds;
      return a.sortOrder - b.sortOrder;
    });
  return open[0] ?? null;
}

/**
 * The ways of attending this event that actually have a price.
 *
 * Taken from the fee rows rather than from the event's `format`, because a
 * hybrid event whose virtual tier nobody priced cannot be attended virtually
 * whatever the format column says.
 */
export function offeredModes(tiers: FeeTier[], format: string): AttendanceMode[] {
  const shape = str(format).toUpperCase();
  if (shape !== 'HYBRID') return [];

  const modes = new Set<AttendanceMode>();
  for (const tier of tiers) {
    if (tier.prices.length === 0) continue;
    if (tier.mode === 'ANY') return ['PHYSICAL', 'VIRTUAL'];
    modes.add(tier.mode);
  }
  return [...modes];
}

/** Every tier a registrant could be shown, for listing the fee table. */
export function tiersToJson(tiers: FeeTier[], at: Date = new Date()) {
  return tiers
    .filter((tier) => tier.prices.length > 0)
    .map((tier) => ({
      label: tier.label,
      attendance_mode: tier.mode,
      prices: pricesToJson(tier.prices),
      available_from: tier.availableFrom || null,
      available_until: tier.availableUntil || null,
      open: tierIsOpen(tier, at),
    }));
}
