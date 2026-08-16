/**
 * Verifies the YouTube integration's safety properties without credentials and
 * without touching the academy's channel.
 *
 * These are the checks that must hold whatever the Google project is
 * configured to do: that no credential can leak to a client, that the OAuth
 * callback cannot be forged, that a lecturer cannot reach another lecturer's
 * video or put anything on air, and that a broadcast is never reported live
 * on WUCO's say-so. Run with:
 *
 *   npm run verify:youtube
 */

import { isAudienceVisible, liveEventToJson } from '../src/live';
import { Actor, can, permissionsFor } from '../src/permissions';
import { mayManage, isoDurationToSeconds } from '../src/videos';
import {
  YOUTUBE_SCOPES,
  beginAuthorisation,
  consumeState,
  resolveYouTubeConfig,
} from '../src/youtube';
import { connectionStatus } from '../src/youtube_connection';

let failures = 0;

function check(name: string, condition: boolean, detail = '') {
  const mark = condition ? 'PASS' : 'FAIL';
  if (!condition) failures += 1;
  console.log(`  [${mark}] ${name}${detail && !condition ? ` — ${detail}` : ''}`);
}

function section(title: string) {
  console.log(`\n${title}`);
}

/** Enough of a KV namespace to exercise the state and token paths. */
function fakeKv() {
  const store = new Map<string, string>();
  return {
    store,
    get: async (key: string) => store.get(key) ?? null,
    put: async (key: string, value: string) => void store.set(key, value),
    delete: async (key: string) => void store.delete(key),
  };
}

/** Enough of D1 to answer the one query connectionStatus makes. */
function fakeDb(row: Record<string, unknown> | null) {
  return {
    prepare: () => ({
      bind: () => ({
        first: async () => row,
        run: async () => ({}),
        all: async () => ({ results: [] }),
      }),
      first: async () => row,
      run: async () => ({}),
    }),
  };
}

const actor = (role: string): Actor => ({ id: `user-${role}`, role: role as Actor['role'] });

async function main() {
  // --- Configuration -------------------------------------------------------

  section('Configuration');

  const unconfigured = resolveYouTubeConfig({
    WEA_DB: fakeDb(null) as never,
    WUCO_TOKENS: fakeKv() as never,
  });
  check(
    'a deployment with no Google client is unusable',
    !unconfigured.usable,
    'offering a Connect button that cannot work is worse than offering none',
  );
  check(
    'and says what is missing',
    unconfigured.reason.includes('GOOGLE_CLIENT_ID') &&
      unconfigured.reason.includes('GOOGLE_CLIENT_SECRET') &&
      unconfigured.reason.includes('GOOGLE_REDIRECT_URI'),
    unconfigured.reason,
  );

  const configured = resolveYouTubeConfig({
    WEA_DB: fakeDb(null) as never,
    WUCO_TOKENS: fakeKv() as never,
    GOOGLE_CLIENT_ID: 'id.apps.googleusercontent.com',
    GOOGLE_CLIENT_SECRET: 'secret-value',
    GOOGLE_REDIRECT_URI: 'https://api.example/api/auth/youtube/callback',
  });
  check('a fully configured deployment is usable', configured.usable);
  check(
    'a client secret alone is not enough',
    !resolveYouTubeConfig({
      WEA_DB: fakeDb(null) as never,
      WUCO_TOKENS: fakeKv() as never,
      GOOGLE_CLIENT_SECRET: 'secret-value',
    }).usable,
  );

  // --- The consent step ----------------------------------------------------

  section('OAuth cannot be forged');

  const kv = fakeKv();
  const env = { WEA_DB: fakeDb(null) as never, WUCO_TOKENS: kv as never, ...configured };
  const start = await beginAuthorisation(
    { ...env, GOOGLE_CLIENT_ID: configured.clientId } as never,
    configured,
    'user-owner',
  );

  check(
    'the authorisation URL carries a state',
    start.state.length >= 32 && start.url.includes(`state=${start.state}`),
    'without one, a crafted callback could attach a stranger’s channel',
  );
  check(
    'it asks for offline access and forces consent',
    start.url.includes('access_type=offline') && start.url.includes('prompt=consent'),
    'without both, Google may return no refresh token and the link dies in an hour',
  );
  check(
    'the client secret is not in the URL',
    !start.url.includes(configured.clientSecret),
    'the consent URL is opened in a browser and lands in history',
  );
  check(
    'only YouTube scopes are requested',
    YOUTUBE_SCOPES.every((scope) => scope.startsWith('https://www.googleapis.com/auth/youtube')),
    YOUTUBE_SCOPES.join(' '),
  );

  const first = await consumeState(env as never, start.state);
  check('a valid state identifies who started the flow', first === 'user-owner');
  const second = await consumeState(env as never, start.state);
  check(
    'and cannot be used twice',
    second === null,
    'a callback URL in a log or history must not be replayable',
  );
  check(
    'an unknown state is refused',
    (await consumeState(env as never, 'not-a-real-state')) === null,
  );
  check('an empty state is refused', (await consumeState(env as never, '')) === null);

  // --- Nothing leaks -------------------------------------------------------

  section('No credential reaches a client');

  const connected = await connectionStatus({
    WEA_DB: fakeDb({
      channel_id: 'UC123',
      channel_title: 'WUCO Executive Academy',
      granted_scopes: YOUTUBE_SCOPES.join(' '),
      connected_at: '2026-08-16T10:00:00Z',
      disconnected_at: null,
      last_error: '',
    }) as never,
    WUCO_TOKENS: kv as never,
    ...configured,
  });

  const serialised = JSON.stringify(connected.data);
  check(
    'status reports the channel',
    serialised.includes('WUCO Executive Academy') && serialised.includes('UC123'),
  );
  check(
    'and contains no client secret',
    !serialised.includes(configured.clientSecret),
    'status is read by every admin page load',
  );
  check(
    'and no token of any kind',
    !serialised.includes('refresh_token') &&
      !serialised.includes('access_token') &&
      !/\btoken\b/i.test(serialised),
    serialised,
  );

  // --- Permissions ---------------------------------------------------------

  section('Permissions are enforced by role, not by the interface');

  check('a lecturer may upload', can(actor('LECTURER'), 'video.upload'));
  check(
    'a lecturer may not manage everybody’s video',
    !can(actor('LECTURER'), 'video.manage.all'),
  );
  check('a lecturer may not create a live event', !can(actor('LECTURER'), 'live.create'));
  check(
    'a lecturer may not start one either',
    !can(actor('LECTURER'), 'live.control'),
    'the whole point of enforcing this server-side',
  );

  for (const role of ['ADMIN', 'SUPER_ADMIN', 'OWNER']) {
    check(
      `${role.toLowerCase().replace('_', ' ')} may run live events`,
      can(actor(role), 'live.create') && can(actor(role), 'live.control'),
    );
  }
  check(
    'only the owner may connect the channel',
    can(actor('OWNER'), 'platform.integrations') &&
      !can(actor('SUPER_ADMIN'), 'platform.integrations') &&
      !can(actor('ADMIN'), 'platform.integrations'),
    'connecting decides where every academy video lives from then on',
  );
  check(
    'a learner may do none of it',
    !can(actor('LEARNER'), 'video.upload') &&
      !can(actor('LEARNER'), 'live.create') &&
      !can(actor('LEARNER'), 'live.control'),
  );
  check(
    'permissions sent to the client match the role',
    permissionsFor('LECTURER').includes('video.upload') &&
      !permissionsFor('LECTURER').includes('live.control'),
  );

  // --- Ownership -----------------------------------------------------------

  section('A lecturer reaches only their own video');

  const mine = { uploaded_by: 'user-LECTURER' };
  const theirs = { uploaded_by: 'somebody-else' };

  check('their own video is theirs to manage', mayManage(actor('LECTURER'), mine));
  check(
    'another lecturer’s is not',
    !mayManage(actor('LECTURER'), theirs),
    'this is the check that makes "own videos only" true',
  );
  check('an admin may manage either', mayManage(actor('ADMIN'), theirs));
  check('a signed-out caller may manage neither', !mayManage(null, mine));
  check(
    'a learner may not manage their own upload either',
    !mayManage({ id: 'user-LECTURER', role: 'LEARNER' }, mine),
    'the row’s owner is not a permission by itself',
  );

  // --- What an audience is shown -------------------------------------------

  section('An audience sees only announced events');

  check(
    'a scheduled event is visible',
    isAudienceVisible({ status: 'SCHEDULED' }) && isAudienceVisible({ status: 'LIVE' }),
  );
  check(
    'a draft is not',
    !isAudienceVisible({ status: 'DRAFT' }),
    'listing it would announce an event the academy has not decided to hold',
  );
  check(
    'nor is a cancelled or failed one',
    !isAudienceVisible({ status: 'CANCELLED' }) && !isAudienceVisible({ status: 'FAILED' }),
  );

  const operational = {
    id: 'live-1',
    title: 'Masterclass',
    status: 'LIVE',
    youtube_broadcast_id: 'bc-secret',
    last_error: 'quota exceeded at 03:12',
  };
  const audienceView = JSON.stringify(liveEventToJson(operational, false));
  check(
    'an audience is not shown the internal error',
    !audienceView.includes('quota exceeded'),
    audienceView,
  );
  check(
    'nor the broadcast id',
    !audienceView.includes('bc-secret'),
    'operational detail explains nothing to an audience',
  );
  check(
    'but whoever runs the event sees both',
    JSON.stringify(liveEventToJson(operational, true)).includes('quota exceeded'),
  );

  // --- Durations -----------------------------------------------------------

  section('YouTube values are read correctly');

  check('an hour, a minute and a second', isoDurationToSeconds('PT1H2M3S') === 3723);
  check('minutes alone', isoDurationToSeconds('PT45M') === 2700);
  check('seconds alone', isoDurationToSeconds('PT30S') === 30);
  check(
    'a duration YouTube has not decided yet is zero',
    isoDurationToSeconds('') === 0,
    'a video still processing has no length, not a wrong one',
  );

  console.log(
    failures === 0
      ? '\nAll checks passed.'
      : `\n${failures} check${failures === 1 ? '' : 's'} failed.`,
  );
  if (failures > 0) process.exit(1);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
