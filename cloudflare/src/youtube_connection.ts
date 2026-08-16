/**
 * Connecting WUCO to the academy's YouTube channel, and reporting on it.
 *
 * The connection is made once, by an owner, and every upload and broadcast
 * afterwards runs on it. That makes this a small module with a large blast
 * radius, so two things are deliberate:
 *
 * **Only `platform.integrations` may connect or disconnect.** That permission
 * belongs to the owner alone. Connecting a channel decides where every academy
 * video will live from then on; it is not an administrative convenience.
 *
 * **Nothing here returns a token.** Status says whether a connection exists,
 * to which channel, and whether it still works — never the credential behind
 * it, in any form.
 */

import { str } from './http';
import {
  YouTubeConfig,
  YouTubeEnv,
  beginAuthorisation,
  channelInfo,
  consumeState,
  disconnect,
  exchangeCode,
  resolveYouTubeConfig,
} from './youtube';

export interface ConnectionResult {
  ok: boolean;
  code?: string;
  message?: string;
  data?: Record<string, unknown>;
}

/** Starts the consent flow and returns the Google URL to send the owner to. */
export async function startConnection(
  env: YouTubeEnv,
  actorId: string,
): Promise<ConnectionResult> {
  const config = resolveYouTubeConfig(env);
  if (!config.usable) {
    return { ok: false, code: 'YOUTUBE_NOT_CONFIGURED', message: config.reason };
  }
  const start = await beginAuthorisation(env, config, actorId);
  return { ok: true, data: { authorisation_url: start.url } };
}

/**
 * Completes the consent flow.
 *
 * The state is checked before the code is spent. An unrecognised state means
 * this callback did not come from a flow WUCO started, which is exactly the
 * shape of an attempt to attach somebody else's channel to the academy — so it
 * is refused before anything is exchanged.
 */
export async function completeConnection(
  env: YouTubeEnv,
  params: URLSearchParams,
): Promise<ConnectionResult> {
  const config = resolveYouTubeConfig(env);
  if (!config.usable) {
    return { ok: false, code: 'YOUTUBE_NOT_CONFIGURED', message: config.reason };
  }

  // Google reports a refused consent here rather than by failing the request.
  const error = str(params.get('error'));
  if (error !== '') {
    return {
      ok: false,
      code: 'YOUTUBE_AUTH_DECLINED',
      message: error === 'access_denied' ? 'The authorisation was declined.' : error,
    };
  }

  const actorId = await consumeState(env, str(params.get('state')));
  if (actorId === null) {
    return {
      ok: false,
      code: 'YOUTUBE_STATE_INVALID',
      message: 'That authorisation link has expired or was already used. Start again.',
    };
  }

  const code = str(params.get('code'));
  if (code === '') {
    return { ok: false, code: 'INVALID_REQUEST', message: 'Google returned no code.' };
  }

  const exchanged = await exchangeCode(env, config, code);
  if (!exchanged.ok) {
    return { ok: false, code: exchanged.code, message: exchanged.message };
  }

  // Which channel this actually connected to is worth knowing immediately: an
  // owner with several Google accounts can authorise the wrong one, and the
  // channel name is how they find out now rather than after uploading.
  const channel = await channelInfo(env, config);
  if (!channel.ok) {
    return { ok: false, code: channel.code, message: channel.message };
  }

  await env.WEA_DB.prepare(
    `INSERT INTO youtube_connections
       (id, channel_id, channel_title, granted_scopes, connected_by,
        connected_at, disconnected_at, last_error, updated_at)
     VALUES ('primary', ?1, ?2, ?3, ?4, CURRENT_TIMESTAMP, NULL, '', CURRENT_TIMESTAMP)
     ON CONFLICT(id) DO UPDATE SET
       channel_id = excluded.channel_id,
       channel_title = excluded.channel_title,
       granted_scopes = excluded.granted_scopes,
       connected_by = excluded.connected_by,
       connected_at = CURRENT_TIMESTAMP,
       disconnected_at = NULL,
       last_error = '',
       updated_at = CURRENT_TIMESTAMP`,
  )
    .bind(
      str(channel.id),
      str(channel.title),
      str(exchanged.scopes),
      actorId,
    )
    .run();

  return {
    ok: true,
    data: {
      connection: {
        connected: true,
        channel_id: channel.id,
        channel_title: channel.title,
      },
    },
  };
}

/**
 * Whether WUCO can currently reach the channel, and to which channel.
 *
 * Deliberately cheap: it reports what WUCO recorded rather than calling Google
 * on every page load. A connection Google has revoked is discovered by the
 * first request that needs it, which marks it disconnected — so this reflects
 * reality without polling for it.
 */
export async function connectionStatus(env: YouTubeEnv): Promise<ConnectionResult> {
  const config = resolveYouTubeConfig(env);
  const row = await env.WEA_DB.prepare(
    'SELECT * FROM youtube_connections WHERE id = ?1',
  )
    .bind('primary')
    .first<Record<string, unknown>>();

  return {
    ok: true,
    data: {
      connection: {
        configured: config.usable,
        configuration_error: config.reason,
        connected: Boolean(row) && row!.disconnected_at === null,
        channel_id: str(row?.channel_id),
        channel_title: str(row?.channel_title),
        granted_scopes: str(row?.granted_scopes).split(' ').filter(Boolean),
        connected_at: row?.connected_at ?? null,
        disconnected_at: row?.disconnected_at ?? null,
        // Why it stopped working, so the interface can say "reconnect" with a
        // reason rather than just failing the next upload.
        last_error: str(row?.last_error),
      },
    },
  };
}

/** Disconnects, revoking at Google as well as forgetting locally. */
export async function removeConnection(env: YouTubeEnv): Promise<ConnectionResult> {
  await disconnect(env);
  return { ok: true, data: { ok: true } };
}

/** The resolved config, for routes that need it after a status check. */
export const youtubeConfig = (env: YouTubeEnv): YouTubeConfig =>
  resolveYouTubeConfig(env);
