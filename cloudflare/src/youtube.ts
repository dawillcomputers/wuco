/**
 * The academy's YouTube channel, reached on WUCO's behalf.
 *
 * WUCO holds one connection to one channel, authorised once by an owner. Every
 * upload and every broadcast afterwards runs on that connection, so a lecturer
 * adding a lesson video never sees a Google prompt and never needs an account
 * on the channel. The academy owns the media; the individual does not.
 *
 * Three rules shape this module.
 *
 * **The refresh token never leaves the Worker, and never enters D1.** It lives
 * in KV, is read only here, and is not returned by any endpoint — not even to
 * an owner, not even masked. A database export is a routine thing for an
 * academy to have; it must not be a way onto the channel.
 *
 * **No access token reaches a client either.** Where a client genuinely has to
 * talk to Google directly — uploading a multi-gigabyte video, which cannot be
 * proxied through a Worker — it is handed a resumable *session URL*, which
 * Google issues for one upload and which authorises nothing else.
 *
 * **Google's answer is the truth.** WUCO records that a broadcast is live after
 * YouTube confirms the transition, never on the click that requested it.
 *
 * Service accounts are not an option here: the YouTube Live API does not accept
 * them, which is why there is an OAuth consent step at all.
 */

import { str } from './http';

const GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token';
const GOOGLE_AUTH_URL = 'https://accounts.google.com/o/oauth2/v2/auth';
const GOOGLE_REVOKE_URL = 'https://oauth2.googleapis.com/revoke';
const YOUTUBE_API = 'https://www.googleapis.com/youtube/v3';
const YOUTUBE_UPLOAD_API = 'https://www.googleapis.com/upload/youtube/v3';

/**
 * What WUCO asks Google for.
 *
 * `youtube.upload` alone can add a video but cannot run a broadcast;
 * `youtube` covers the live control WUCO needs; `youtube.readonly` lets the
 * academy list what is already on the channel. Nothing here grants access to
 * the owner's other Google data, and no scope is requested that is not used by
 * a route in this codebase.
 */
export const YOUTUBE_SCOPES = [
  'https://www.googleapis.com/auth/youtube.upload',
  'https://www.googleapis.com/auth/youtube',
  'https://www.googleapis.com/auth/youtube.readonly',
];

/** KV keys. Prefixed so the namespace can hold other things safely. */
const REFRESH_TOKEN_KEY = 'youtube:refresh_token';
const ACCESS_TOKEN_KEY = 'youtube:access_token';
const STATE_PREFIX = 'youtube:oauth_state:';

/** How long an unused OAuth state stays valid. */
const STATE_TTL_SECONDS = 600;

/**
 * Refresh this long before the token actually expires.
 *
 * A token that expires between the check and the call is an error in the
 * middle of an upload, so the window is treated as shorter than Google says.
 */
const EXPIRY_SKEW_SECONDS = 120;

export interface YouTubeEnv {
  WEA_DB: D1Database;
  WUCO_TOKENS: KVNamespace;
  GOOGLE_CLIENT_ID?: string;
  GOOGLE_CLIENT_SECRET?: string;
  GOOGLE_REDIRECT_URI?: string;
}

export interface YouTubeConfig {
  clientId: string;
  clientSecret: string;
  redirectUri: string;
  /** False when the deployment cannot complete an OAuth exchange at all. */
  usable: boolean;
  reason: string;
}

/**
 * Whether this deployment can talk to Google, and why not when it cannot.
 *
 * Reported rather than thrown so the admin interface can say "YouTube is not
 * configured" instead of offering a Connect button that fails on click.
 */
export function resolveYouTubeConfig(env: YouTubeEnv): YouTubeConfig {
  const clientId = str(env.GOOGLE_CLIENT_ID);
  const clientSecret = str(env.GOOGLE_CLIENT_SECRET);
  const redirectUri = str(env.GOOGLE_REDIRECT_URI);

  const missing: string[] = [];
  if (clientId === '') missing.push('GOOGLE_CLIENT_ID');
  if (clientSecret === '') missing.push('GOOGLE_CLIENT_SECRET');
  if (redirectUri === '') missing.push('GOOGLE_REDIRECT_URI');

  return {
    clientId,
    clientSecret,
    redirectUri,
    usable: missing.length === 0,
    reason:
      missing.length === 0 ? '' : `Not configured: ${missing.join(', ')} unset.`,
  };
}

// ---------------------------------------------------------------------------
// The consent step
// ---------------------------------------------------------------------------

/** Random, URL-safe, and long enough not to be guessed. */
function randomState(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return [...bytes].map((byte) => byte.toString(16).padStart(2, '0')).join('');
}

export interface AuthorisationStart {
  url: string;
  state: string;
}

/**
 * Where to send the owner to authorise WUCO, and the state that proves the
 * answer came back from the same request.
 *
 * The `state` is not decoration. Without it, anyone who can get an owner to
 * open a crafted callback URL can connect *their* channel to WUCO, and every
 * subsequent academy upload lands on a stranger's account. It is random,
 * single-use, stored server-side with a short life, and the id of the actor
 * who started the flow is stored with it so the callback cannot be completed
 * by a different account.
 *
 * `access_type=offline` with `prompt=consent` is what makes Google return a
 * refresh token — without both, a reconnect can come back with none, and the
 * connection silently lasts an hour.
 */
export async function beginAuthorisation(
  env: YouTubeEnv,
  config: YouTubeConfig,
  actorId: string,
): Promise<AuthorisationStart> {
  const state = randomState();
  await env.WUCO_TOKENS.put(`${STATE_PREFIX}${state}`, actorId, {
    expirationTtl: STATE_TTL_SECONDS,
  });

  const params = new URLSearchParams({
    client_id: config.clientId,
    redirect_uri: config.redirectUri,
    response_type: 'code',
    scope: YOUTUBE_SCOPES.join(' '),
    access_type: 'offline',
    prompt: 'consent',
    include_granted_scopes: 'true',
    state,
  });
  return { url: `${GOOGLE_AUTH_URL}?${params}`, state };
}

/**
 * Checks a returned state and spends it.
 *
 * Deleted on use, so a callback URL that leaks into a log or a browser history
 * cannot be replayed.
 */
export async function consumeState(
  env: YouTubeEnv,
  state: string,
): Promise<string | null> {
  const key = `${STATE_PREFIX}${str(state)}`;
  if (str(state) === '') return null;
  const actorId = await env.WUCO_TOKENS.get(key);
  if (actorId === null) return null;
  await env.WUCO_TOKENS.delete(key);
  return actorId;
}

interface TokenResponse {
  access_token?: string;
  refresh_token?: string;
  expires_in?: number;
  scope?: string;
  error?: string;
  error_description?: string;
}

export interface ExchangeResult {
  ok: boolean;
  code?: string;
  message?: string;
  scopes?: string;
}

/**
 * Trades the authorisation code for tokens and stores them.
 *
 * A response without a refresh token is refused rather than accepted: it would
 * appear to work and then stop within the hour, which is a worse failure than
 * being told now to try again.
 */
export async function exchangeCode(
  env: YouTubeEnv,
  config: YouTubeConfig,
  code: string,
): Promise<ExchangeResult> {
  const response = await fetch(GOOGLE_TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      code,
      client_id: config.clientId,
      client_secret: config.clientSecret,
      redirect_uri: config.redirectUri,
      grant_type: 'authorization_code',
    }),
  });

  const body = (await response.json().catch(() => ({}))) as TokenResponse;
  if (!response.ok || str(body.access_token) === '') {
    return {
      ok: false,
      code: 'YOUTUBE_AUTH_FAILED',
      message: str(body.error_description) || str(body.error) || 'Google refused the authorisation.',
    };
  }
  if (str(body.refresh_token) === '') {
    return {
      ok: false,
      code: 'YOUTUBE_NO_REFRESH_TOKEN',
      message:
        'Google returned no refresh token. Remove WUCO from the account’s ' +
        'third-party access and connect again.',
    };
  }

  await env.WUCO_TOKENS.put(REFRESH_TOKEN_KEY, str(body.refresh_token));
  await storeAccessToken(env, str(body.access_token), body.expires_in ?? 3600);
  return { ok: true, scopes: str(body.scope) };
}

/** Caches the access token in KV, expiring it slightly early on purpose. */
async function storeAccessToken(
  env: YouTubeEnv,
  token: string,
  expiresIn: number,
): Promise<string> {
  const ttl = Math.max(60, Math.floor(expiresIn) - EXPIRY_SKEW_SECONDS);
  // KV requires at least 60s; anything shorter is not worth caching anyway.
  await env.WUCO_TOKENS.put(ACCESS_TOKEN_KEY, token, { expirationTtl: ttl });
  return new Date(Date.now() + ttl * 1000).toISOString();
}

// ---------------------------------------------------------------------------
// Staying connected
// ---------------------------------------------------------------------------

export interface AccessToken {
  ok: boolean;
  token?: string;
  code?: string;
  message?: string;
}

/**
 * A usable access token, refreshed if the cached one has gone.
 *
 * Callers never handle the refresh token themselves — this is the only place
 * it is read, so there is one path onto the channel rather than one per
 * feature.
 */
export async function accessToken(
  env: YouTubeEnv,
  config: YouTubeConfig,
): Promise<AccessToken> {
  if (!config.usable) {
    return { ok: false, code: 'YOUTUBE_NOT_CONFIGURED', message: config.reason };
  }

  const cached = await env.WUCO_TOKENS.get(ACCESS_TOKEN_KEY);
  if (cached) return { ok: true, token: cached };

  const refresh = await env.WUCO_TOKENS.get(REFRESH_TOKEN_KEY);
  if (!refresh) {
    return {
      ok: false,
      code: 'YOUTUBE_NOT_CONNECTED',
      message: 'No YouTube channel is connected.',
    };
  }

  const response = await fetch(GOOGLE_TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      refresh_token: refresh,
      client_id: config.clientId,
      client_secret: config.clientSecret,
      grant_type: 'refresh_token',
    }),
  });
  const body = (await response.json().catch(() => ({}))) as TokenResponse;

  if (!response.ok || str(body.access_token) === '') {
    // Google refuses a refresh token that has been revoked, or whose consent
    // was withdrawn. That is not a transient error and retrying will not fix
    // it, so the connection is marked dead and the academy is asked to
    // reconnect rather than left watching uploads fail.
    const message =
      str(body.error_description) || str(body.error) || 'Google refused the refresh token.';
    await markDisconnected(env, message);
    return { ok: false, code: 'YOUTUBE_RECONNECT_REQUIRED', message };
  }

  const expiresAt = await storeAccessToken(
    env,
    str(body.access_token),
    body.expires_in ?? 3600,
  );
  await env.WEA_DB.prepare(
    `UPDATE youtube_connections
        SET token_expires_at = ?1, last_error = '', updated_at = CURRENT_TIMESTAMP
      WHERE id = 'primary'`,
  )
    .bind(expiresAt)
    .run();

  return { ok: true, token: str(body.access_token) };
}

/** Records that the connection has stopped working, and why. */
export async function markDisconnected(
  env: YouTubeEnv,
  reason: string,
): Promise<void> {
  await env.WUCO_TOKENS.delete(ACCESS_TOKEN_KEY);
  await env.WEA_DB.prepare(
    `UPDATE youtube_connections
        SET disconnected_at = CURRENT_TIMESTAMP, last_error = ?1,
            updated_at = CURRENT_TIMESTAMP
      WHERE id = 'primary'`,
  )
    .bind(reason.slice(0, 500))
    .run();
}

/**
 * Forgets the connection, and tells Google to forget it too.
 *
 * Deleting WUCO's copy alone would leave a refresh token outstanding on the
 * Google account that nothing here can any longer revoke, so the revocation is
 * attempted first — but a failure there does not stop the local delete, since
 * the alternative is a connection the academy cannot get rid of.
 */
export async function disconnect(env: YouTubeEnv): Promise<void> {
  const refresh = await env.WUCO_TOKENS.get(REFRESH_TOKEN_KEY);
  if (refresh) {
    try {
      await fetch(GOOGLE_REVOKE_URL, {
        method: 'POST',
        headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
        body: new URLSearchParams({ token: refresh }),
      });
    } catch {
      // Revocation is best effort; the local delete below is not.
    }
  }
  await env.WUCO_TOKENS.delete(REFRESH_TOKEN_KEY);
  await env.WUCO_TOKENS.delete(ACCESS_TOKEN_KEY);
  await env.WEA_DB.prepare('DELETE FROM youtube_connections WHERE id = ?1')
    .bind('primary')
    .run();
}

// ---------------------------------------------------------------------------
// Talking to YouTube
// ---------------------------------------------------------------------------

export interface ApiResult<T = Record<string, unknown>> {
  ok: boolean;
  status: number;
  data: T;
  code?: string;
  message?: string;
}

/**
 * One call to the YouTube Data API.
 *
 * Every route goes through here so that authorisation, error shape and the
 * "reconnect required" case are handled once. A 401 means the token was
 * rejected despite being fresh, which in practice means consent is gone.
 */
export async function youtubeApi<T = Record<string, unknown>>(
  env: YouTubeEnv,
  config: YouTubeConfig,
  path: string,
  init: RequestInit & { query?: Record<string, string> } = {},
): Promise<ApiResult<T>> {
  const token = await accessToken(env, config);
  if (!token.ok) {
    return {
      ok: false,
      status: 503,
      data: {} as T,
      code: token.code,
      message: token.message,
    };
  }

  const query = init.query ? `?${new URLSearchParams(init.query)}` : '';
  const response = await fetch(`${YOUTUBE_API}${path}${query}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${token.token}`,
      'Content-Type': 'application/json',
      ...(init.headers ?? {}),
    },
  });

  const data = (await response.json().catch(() => ({}))) as T & {
    error?: { message?: string; errors?: { reason?: string }[] };
  };

  if (!response.ok) {
    const message = str(data.error?.message) || `YouTube returned ${response.status}.`;
    if (response.status === 401) {
      await markDisconnected(env, message);
      return {
        ok: false,
        status: 401,
        data: {} as T,
        code: 'YOUTUBE_RECONNECT_REQUIRED',
        message,
      };
    }
    return {
      ok: false,
      status: response.status,
      data: {} as T,
      code: 'YOUTUBE_API_ERROR',
      message,
    };
  }

  return { ok: true, status: response.status, data };
}

// ---------------------------------------------------------------------------
// Uploads
// ---------------------------------------------------------------------------

export interface UploadSession {
  ok: boolean;
  uploadUrl?: string;
  code?: string;
  message?: string;
}

/**
 * Opens a resumable upload and returns the URL the file should be sent to.
 *
 * **Why the bytes do not pass through this Worker.** A YouTube video may be up
 * to 256 GB. A Worker has a fraction of that in memory and a request-size
 * ceiling far below it, so proxying the file would cap WUCO's uploads at
 * something like the size of a slide deck and would burn Worker time in
 * proportion to every gigabyte the academy ever publishes. Google's resumable
 * protocol exists for exactly this: WUCO authenticates and describes the
 * video, Google issues a one-shot session URL, and the client sends bytes
 * straight to Google.
 *
 * What the client receives is a URL that accepts the bytes of *this* upload
 * and authorises nothing else — not another upload, not a read of the channel,
 * not anything if the session expires. The access token stays here. That is
 * the property that makes handing anything to the client acceptable at all.
 *
 * A resumable session also survives a dropped connection, which matters when
 * a lecturer is uploading a lecture over an unreliable line.
 */
export async function createUploadSession(
  env: YouTubeEnv,
  config: YouTubeConfig,
  video: {
    title: string;
    description: string;
    privacyStatus: string;
    categoryId?: string;
    tags?: string[];
  },
  file: { contentType: string; sizeBytes: number },
): Promise<UploadSession> {
  const token = await accessToken(env, config);
  if (!token.ok) {
    return { ok: false, code: token.code, message: token.message };
  }

  const body = {
    snippet: {
      title: video.title.slice(0, 100),
      description: video.description.slice(0, 5000),
      // 27 is "Education". The academy's videos are teaching material by
      // default; anything else is a deliberate choice by the uploader.
      categoryId: video.categoryId ?? '27',
      tags: video.tags ?? [],
    },
    status: {
      privacyStatus: video.privacyStatus.toLowerCase(),
      // WUCO's own upload; asserting it is required by the API.
      selfDeclaredMadeForKids: false,
    },
  };

  const response = await fetch(
    `${YOUTUBE_UPLOAD_API}/videos?${new URLSearchParams({
      uploadType: 'resumable',
      part: 'snippet,status',
    })}`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token.token}`,
        'Content-Type': 'application/json; charset=UTF-8',
        'X-Upload-Content-Type': file.contentType,
        'X-Upload-Content-Length': String(file.sizeBytes),
      },
      body: JSON.stringify(body),
    },
  );

  if (!response.ok) {
    const detail = (await response.json().catch(() => ({}))) as {
      error?: { message?: string };
    };
    const message = str(detail.error?.message) || `YouTube returned ${response.status}.`;
    if (response.status === 401) await markDisconnected(env, message);
    return {
      ok: false,
      code: response.status === 401 ? 'YOUTUBE_RECONNECT_REQUIRED' : 'YOUTUBE_API_ERROR',
      message,
    };
  }

  const uploadUrl = response.headers.get('Location');
  if (!uploadUrl) {
    return {
      ok: false,
      code: 'YOUTUBE_API_ERROR',
      message: 'YouTube accepted the request but returned no upload session.',
    };
  }
  return { ok: true, uploadUrl };
}

// ---------------------------------------------------------------------------
// Live broadcasts
// ---------------------------------------------------------------------------

export interface BroadcastResult {
  ok: boolean;
  broadcastId?: string;
  streamId?: string;
  watchUrl?: string;
  code?: string;
  message?: string;
  /** YouTube's HTTP status on failure, so a 404 can be told from a refusal. */
  status?: number;
}

/** The public watch URL for a broadcast or video id. */
export const watchUrlFor = (videoId: string) =>
  `https://www.youtube.com/watch?v=${videoId}`;

/**
 * Creates the broadcast an audience will eventually watch.
 *
 * This does not put anything on air and does not touch a camera. It reserves
 * the event on YouTube — title, description, scheduled time, visibility — and
 * gives WUCO the id it will use to bind a stream and, later, to go live.
 */
export async function createBroadcast(
  env: YouTubeEnv,
  config: YouTubeConfig,
  event: {
    title: string;
    description: string;
    scheduledStart: string;
    scheduledEnd?: string;
    privacyStatus: string;
  },
): Promise<BroadcastResult> {
  const result = await youtubeApi<{ id?: string }>(env, config, '/liveBroadcasts', {
    method: 'POST',
    query: { part: 'snippet,status,contentDetails' },
    body: JSON.stringify({
      snippet: {
        title: event.title.slice(0, 100),
        description: event.description.slice(0, 5000),
        scheduledStartTime: event.scheduledStart,
        ...(event.scheduledEnd ? { scheduledEndTime: event.scheduledEnd } : {}),
      },
      status: {
        privacyStatus: event.privacyStatus.toLowerCase(),
        selfDeclaredMadeForKids: false,
      },
      contentDetails: {
        // WUCO drives the transitions itself, from its own controls, so that
        // "live" in WUCO and "live" on YouTube mean the same thing.
        enableAutoStart: false,
        enableAutoStop: false,
        // The recording remains afterwards as the event's own video.
        recordFromStart: true,
        enableDvr: true,
      },
    }),
  });

  if (!result.ok) return { ok: false, code: result.code, message: result.message };
  const broadcastId = str(result.data.id);
  return { ok: true, broadcastId, watchUrl: watchUrlFor(broadcastId) };
}

/**
 * Creates the ingest stream an encoder pushes video into.
 *
 * The stream is what carries the actual audio and video; the broadcast is only
 * the event around it. They are created separately by YouTube's design and
 * mean nothing to each other until bound.
 */
export async function createStream(
  env: YouTubeEnv,
  config: YouTubeConfig,
  title: string,
): Promise<BroadcastResult> {
  const result = await youtubeApi<{ id?: string }>(env, config, '/liveStreams', {
    method: 'POST',
    query: { part: 'snippet,cdn,contentDetails' },
    body: JSON.stringify({
      snippet: { title: `${title} — WUCO ingest`.slice(0, 128) },
      cdn: {
        // RTMP at a variable resolution is what OBS and hardware encoders
        // send by default, and lets the encoder decide quality from the
        // connection it actually has.
        ingestionType: 'rtmp',
        resolution: 'variable',
        frameRate: 'variable',
      },
      contentDetails: { isReusable: true },
    }),
  });

  if (!result.ok) return { ok: false, code: result.code, message: result.message };
  return { ok: true, streamId: str(result.data.id) };
}

/** Attaches a stream to a broadcast, so the feed has somewhere to appear. */
export async function bindStream(
  env: YouTubeEnv,
  config: YouTubeConfig,
  broadcastId: string,
  streamId: string,
): Promise<BroadcastResult> {
  const result = await youtubeApi<{ id?: string }>(env, config, '/liveBroadcasts/bind', {
    method: 'POST',
    query: { part: 'id,contentDetails', id: broadcastId, streamId },
  });
  if (!result.ok) return { ok: false, code: result.code, message: result.message };
  return { ok: true, broadcastId, streamId };
}

/**
 * Where the encoder should send video, and the key that authorises it.
 *
 * Fetched on demand and never stored: a stream key is a credential that lets
 * anybody holding it broadcast to the academy's channel. It is shown to an
 * admin who is about to configure an encoder, and that is the whole of its
 * life inside WUCO.
 */
export async function ingestionDetails(
  env: YouTubeEnv,
  config: YouTubeConfig,
  streamId: string,
): Promise<{
  ok: boolean;
  address?: string;
  streamName?: string;
  status?: string;
  code?: string;
  message?: string;
}> {
  const result = await youtubeApi<{
    items?: {
      cdn?: { ingestionInfo?: { ingestionAddress?: string; streamName?: string } };
      status?: { streamStatus?: string };
    }[];
  }>(env, config, '/liveStreams', {
    method: 'GET',
    query: { part: 'cdn,status', id: streamId },
  });

  if (!result.ok) return { ok: false, code: result.code, message: result.message };
  const item = result.data.items?.[0];
  if (!item) {
    return { ok: false, code: 'NOT_FOUND', message: 'That stream no longer exists.' };
  }
  return {
    ok: true,
    address: str(item.cdn?.ingestionInfo?.ingestionAddress),
    streamName: str(item.cdn?.ingestionInfo?.streamName),
    status: str(item.status?.streamStatus),
  };
}

/** Whether a bound stream is actually receiving video right now. */
export async function streamIsActive(
  env: YouTubeEnv,
  config: YouTubeConfig,
  streamId: string,
): Promise<boolean> {
  const details = await ingestionDetails(env, config, streamId);
  return details.ok && details.status === 'active';
}

/**
 * Moves a broadcast to a new state — `testing`, `live` or `complete`.
 *
 * YouTube refuses a transition it considers invalid, and that refusal is
 * passed back rather than smoothed over: a broadcast that will not go live
 * because nothing is being sent to it is a fact the admin needs, not an error
 * to hide behind a retry.
 */
export async function transitionBroadcast(
  env: YouTubeEnv,
  config: YouTubeConfig,
  broadcastId: string,
  status: 'testing' | 'live' | 'complete',
): Promise<BroadcastResult> {
  const result = await youtubeApi<{ id?: string }>(env, config, '/liveBroadcasts/transition', {
    method: 'POST',
    query: { part: 'id,status', id: broadcastId, broadcastStatus: status },
  });
  if (!result.ok) {
    return {
      ok: false,
      code: result.code,
      message: result.message,
      status: result.status,
    };
  }
  return { ok: true, broadcastId };
}

/** The channel WUCO is connected to, as Google reports it. */
export async function channelInfo(
  env: YouTubeEnv,
  config: YouTubeConfig,
): Promise<{ ok: boolean; id?: string; title?: string; code?: string; message?: string }> {
  const result = await youtubeApi<{
    items?: { id?: string; snippet?: { title?: string } }[];
  }>(env, config, '/channels', {
    method: 'GET',
    query: { part: 'snippet', mine: 'true' },
  });

  if (!result.ok) return { ok: false, code: result.code, message: result.message };
  const item = result.data.items?.[0];
  if (!item) {
    return {
      ok: false,
      code: 'YOUTUBE_NO_CHANNEL',
      message: 'That Google account has no YouTube channel.',
    };
  }
  return { ok: true, id: str(item.id), title: str(item.snippet?.title) };
}
