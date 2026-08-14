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
    unusable.getPaymentMethods(['card', 'bank_transfer']).length === 0,
    'offering a method that cannot complete is worse than offering none',
  );

  const service = new FlutterwavePaymentService(sandbox);
  check(
    'an event with nothing enabled offers nothing',
    service.getPaymentMethods([]).length === 0,
  );

  const offered = service.getPaymentMethods(['bank_transfer', 'ussd', 'nonsense']);
  check('only enabled methods are offered', offered.length === 2, `${offered.length}`);
  check(
    'an unknown method key is ignored',
    !offered.some((method) => method.key === 'nonsense'),
  );

  const card = service.getPaymentMethods(['card'])[0];
  check(
    'card is a redirect, never a direct charge',
    card?.flow === 'redirect',
    'a direct card charge would put WEA in PCI scope',
  );
  const transfer = service.getPaymentMethods(['bank_transfer'])[0];
  check('bank transfer is a direct charge', transfer?.flow === 'directCharge');

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
    methods: secretService.getPaymentMethods([
      'card',
      'bank_transfer',
      'ussd',
      'opay',
      'nqr',
      'bank_account',
    ]),
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
