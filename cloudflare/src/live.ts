/**
 * WUCO live events, carried by YouTube broadcasts.
 *
 * YouTube keeps two things apart, and so does this module, because conflating
 * them is what produces an empty screen in front of an audience:
 *
 *   - a **broadcast** is the event people watch — a title, a time, a watch
 *     page. Creating one puts nothing on air.
 *   - a **stream** is the ingest endpoint an encoder pushes audio and video
 *     into. Until something is bound to the broadcast and actually sending,
 *     there is nothing to watch.
 *
 * So WUCO's "Start live" is not a camera button. It asks YouTube to transition
 * a broadcast that already has video arriving at it. The video itself comes
 * from an encoder — OBS or a hardware unit — pointed at the ingest address
 * this module hands out. That is the arrangement every professional channel
 * uses, and it is why `start` refuses when nothing is being received: telling
 * an audience an event is live when the screen is black is the failure this
 * whole module exists to prevent.
 *
 * Creating an event and putting it on air are separate permissions
 * (`live.create`, `live.control`) because they are separate risks.
 */

import { newId } from './auth';
import { num, str } from './http';
import { Actor } from './permissions';
import {
  YouTubeConfig,
  YouTubeEnv,
  bindStream,
  createBroadcast,
  createStream,
  ingestionDetails,
  streamIsActive,
  transitionBroadcast,
  watchUrlFor,
  youtubeApi,
} from './youtube';

export interface LiveResult {
  ok: boolean;
  code?: string;
  message?: string;
  data?: Record<string, unknown>;
}

const PRIVACY = ['PRIVATE', 'UNLISTED', 'PUBLIC'];

/**
 * Schedules an event: creates the broadcast, a stream, and binds them.
 *
 * All three happen together because an event with a broadcast and no bound
 * stream is one that cannot be started, and discovering that at the scheduled
 * hour is too late. If any step fails the row is kept in `FAILED` with the
 * reason, rather than deleted — an administrator needs to see what went wrong,
 * and a half-made broadcast on YouTube should not become invisible to WUCO.
 */
export async function createLiveEvent(
  env: YouTubeEnv,
  config: YouTubeConfig,
  actor: Actor,
  body: Record<string, unknown>,
): Promise<LiveResult> {
  const title = str(body.title);
  if (title === '') {
    return { ok: false, code: 'INVALID_REQUEST', message: 'A title is required.' };
  }

  const scheduledStart = str(body.scheduled_start);
  if (scheduledStart === '' || Number.isNaN(Date.parse(scheduledStart))) {
    return {
      ok: false,
      code: 'INVALID_REQUEST',
      message: 'A scheduled start time is required.',
    };
  }
  const scheduledEnd = str(body.scheduled_end);
  if (scheduledEnd !== '' && Number.isNaN(Date.parse(scheduledEnd))) {
    return { ok: false, code: 'INVALID_REQUEST', message: 'The end time is not a date.' };
  }
  if (scheduledEnd !== '' && Date.parse(scheduledEnd) <= Date.parse(scheduledStart)) {
    return {
      ok: false,
      code: 'INVALID_REQUEST',
      message: 'The event cannot end before it starts.',
    };
  }

  const requested = str(body.privacy_status).toUpperCase();
  // Unlisted by default: an event is normally for the people invited to it,
  // and a public broadcast is a deliberate decision.
  const privacy = PRIVACY.includes(requested) ? requested : 'UNLISTED';

  const id = `live-${newId()}`;
  await env.WEA_DB.prepare(
    `INSERT INTO youtube_live_events
       (id, title, description, speaker, scheduled_start, scheduled_end,
        privacy_status, status, programme_id, event_id, created_by, created_by_role)
     VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, 'DRAFT', ?8, ?9, ?10, ?11)`,
  )
    .bind(
      id,
      title,
      str(body.description),
      str(body.speaker),
      new Date(scheduledStart).toISOString(),
      scheduledEnd === '' ? null : new Date(scheduledEnd).toISOString(),
      privacy,
      str(body.programme_id) || null,
      str(body.event_id) || null,
      actor.id,
      actor.role,
    )
    .run();

  const fail = async (code: string, message?: string): Promise<LiveResult> => {
    await env.WEA_DB.prepare(
      `UPDATE youtube_live_events
          SET status = 'FAILED', last_error = ?1, updated_at = CURRENT_TIMESTAMP
        WHERE id = ?2`,
    )
      .bind(str(message).slice(0, 500), id)
      .run();
    return { ok: false, code, message };
  };

  const broadcast = await createBroadcast(env, config, {
    title,
    description: str(body.description),
    scheduledStart: new Date(scheduledStart).toISOString(),
    scheduledEnd: scheduledEnd === '' ? undefined : new Date(scheduledEnd).toISOString(),
    privacyStatus: privacy,
  });
  if (!broadcast.ok) return fail(broadcast.code ?? 'YOUTUBE_API_ERROR', broadcast.message);

  const stream = await createStream(env, config, title);
  if (!stream.ok) return fail(stream.code ?? 'YOUTUBE_API_ERROR', stream.message);

  const bound = await bindStream(
    env,
    config,
    str(broadcast.broadcastId),
    str(stream.streamId),
  );
  if (!bound.ok) return fail(bound.code ?? 'YOUTUBE_API_ERROR', bound.message);

  await env.WEA_DB.prepare(
    `UPDATE youtube_live_events
        SET youtube_broadcast_id = ?1, youtube_stream_id = ?2, watch_url = ?3,
            status = 'SCHEDULED', last_error = '', updated_at = CURRENT_TIMESTAMP
      WHERE id = ?4`,
  )
    .bind(
      str(broadcast.broadcastId),
      str(stream.streamId),
      str(broadcast.watchUrl),
      id,
    )
    .run();

  const row = await liveEventRow(env.WEA_DB, id);
  return { ok: true, data: { live_event: liveEventToJson(row ?? {}, true) } };
}

export const liveEventRow = (db: D1Database, id: string) =>
  db
    .prepare('SELECT * FROM youtube_live_events WHERE id = ?1')
    .bind(id)
    .first<Record<string, unknown>>();

/**
 * Puts the event on air.
 *
 * Two things are checked before YouTube is asked, and both exist because the
 * alternative is an audience watching nothing:
 *
 *   1. the broadcast has a bound stream at all, and
 *   2. that stream is *actually receiving video right now*.
 *
 * The second is the one that matters. YouTube will accept a transition to
 * `live` for a broadcast whose encoder is not connected, and the result is a
 * live event showing a black screen to everyone who was invited. Refusing here
 * with a plain explanation — start the encoder first — is worth far more than
 * a button that always appears to work.
 *
 * WUCO's own status is written only after YouTube confirms the transition.
 */
export async function startLiveEvent(
  env: YouTubeEnv,
  config: YouTubeConfig,
  actor: Actor,
  id: string,
): Promise<LiveResult> {
  const row = await liveEventRow(env.WEA_DB, id);
  if (!row) return { ok: false, code: 'NOT_FOUND' };

  const status = str(row.status);
  if (status === 'LIVE') return { ok: false, code: 'ALREADY_LIVE' };
  if (status === 'COMPLETE' || status === 'CANCELLED') {
    return {
      ok: false,
      code: 'EVENT_FINISHED',
      message: 'That event has already finished.',
    };
  }

  const broadcastId = str(row.youtube_broadcast_id);
  const streamId = str(row.youtube_stream_id);
  if (broadcastId === '' || streamId === '') {
    return {
      ok: false,
      code: 'NOT_READY',
      message: 'This event has no broadcast on YouTube yet.',
    };
  }

  if (!(await streamIsActive(env, config, streamId))) {
    return {
      ok: false,
      code: 'STREAM_NOT_ACTIVE',
      message:
        'YouTube is not receiving video yet. Start the encoder and wait for it ' +
        'to connect, then start the event.',
    };
  }

  const result = await transitionBroadcast(env, config, broadcastId, 'live');
  if (!result.ok) {
    await env.WEA_DB.prepare(
      `UPDATE youtube_live_events
          SET last_error = ?1, updated_at = CURRENT_TIMESTAMP
        WHERE id = ?2`,
    )
      .bind(str(result.message).slice(0, 500), id)
      .run();
    return { ok: false, code: result.code, message: result.message };
  }

  await env.WEA_DB.prepare(
    `UPDATE youtube_live_events
        SET status = 'LIVE', actual_start = CURRENT_TIMESTAMP, started_by = ?1,
            youtube_video_id = ?2, watch_url = ?3, last_error = '',
            updated_at = CURRENT_TIMESTAMP
      WHERE id = ?4`,
  )
    .bind(actor.id, broadcastId, watchUrlFor(broadcastId), id)
    .run();

  const updated = await liveEventRow(env.WEA_DB, id);
  return { ok: true, data: { live_event: liveEventToJson(updated ?? {}, true) } };
}

/**
 * Takes the event off air.
 *
 * A broadcast YouTube has already completed — because the encoder stopped, or
 * an admin ended it from YouTube directly — is treated as success: the state
 * being asked for is the state that holds, and refusing would leave WUCO
 * permanently showing an event as live that is not.
 */
export async function endLiveEvent(
  env: YouTubeEnv,
  config: YouTubeConfig,
  actor: Actor,
  id: string,
): Promise<LiveResult> {
  const row = await liveEventRow(env.WEA_DB, id);
  if (!row) return { ok: false, code: 'NOT_FOUND' };
  if (str(row.status) === 'COMPLETE') return { ok: false, code: 'ALREADY_ENDED' };

  const broadcastId = str(row.youtube_broadcast_id);
  if (broadcastId !== '') {
    const result = await transitionBroadcast(env, config, broadcastId, 'complete');
    if (!result.ok && result.status !== 404 && !alreadyComplete(result.message)) {
      return { ok: false, code: result.code, message: result.message };
    }
  }

  await env.WEA_DB.prepare(
    `UPDATE youtube_live_events
        SET status = 'COMPLETE', actual_end = CURRENT_TIMESTAMP, ended_by = ?1,
            updated_at = CURRENT_TIMESTAMP
      WHERE id = ?2`,
  )
    .bind(actor.id, id)
    .run();

  const updated = await liveEventRow(env.WEA_DB, id);
  return { ok: true, data: { live_event: liveEventToJson(updated ?? {}, true) } };
}

/** YouTube's way of saying the broadcast was already in the target state. */
const alreadyComplete = (message?: string) =>
  (message ?? '').toLowerCase().includes('invalid transition');

/**
 * What YouTube currently thinks, rather than what WUCO last recorded.
 *
 * Used by the live control screen while an event is running, and reconciled into
 * WUCO's own status so an event ended outside WUCO does not stay `LIVE` here
 * forever.
 */
export async function liveEventStatus(
  env: YouTubeEnv,
  config: YouTubeConfig,
  id: string,
): Promise<LiveResult> {
  const row = await liveEventRow(env.WEA_DB, id);
  if (!row) return { ok: false, code: 'NOT_FOUND' };

  const broadcastId = str(row.youtube_broadcast_id);
  if (broadcastId === '') {
    return { ok: true, data: { live_event: liveEventToJson(row, true), youtube: null } };
  }

  const result = await youtubeApi<{
    items?: { status?: { lifeCycleStatus?: string } }[];
  }>(env, config, '/liveBroadcasts', {
    method: 'GET',
    query: { part: 'status', id: broadcastId },
  });
  if (!result.ok) {
    return { ok: true, data: { live_event: liveEventToJson(row, true), youtube: null } };
  }

  const lifecycle = str(result.data.items?.[0]?.status?.lifeCycleStatus);
  // `complete` and `revoked` are final states; anything else leaves WUCO's own
  // record alone, since WUCO is the one driving the transitions.
  if (
    (lifecycle === 'complete' || lifecycle === 'revoked') &&
    str(row.status) === 'LIVE'
  ) {
    await env.WEA_DB.prepare(
      `UPDATE youtube_live_events
          SET status = 'COMPLETE', actual_end = CURRENT_TIMESTAMP,
              updated_at = CURRENT_TIMESTAMP
        WHERE id = ?1`,
    )
      .bind(id)
      .run();
  }

  const stream = str(row.youtube_stream_id);
  const receiving = stream === '' ? false : await streamIsActive(env, config, stream);
  const updated = await liveEventRow(env.WEA_DB, id);
  return {
    ok: true,
    data: {
      live_event: liveEventToJson(updated ?? row, true),
      youtube: { lifecycle_status: lifecycle, receiving_video: receiving },
    },
  };
}

/**
 * Where the encoder should point, and the key that authorises it.
 *
 * Fetched from YouTube each time and never stored: this is the credential that
 * lets anything broadcast to the academy's channel, and it belongs in an
 * encoder's settings box, not in WUCO's database.
 */
export async function liveEventIngestion(
  env: YouTubeEnv,
  config: YouTubeConfig,
  id: string,
): Promise<LiveResult> {
  const row = await liveEventRow(env.WEA_DB, id);
  if (!row) return { ok: false, code: 'NOT_FOUND' };

  const streamId = str(row.youtube_stream_id);
  if (streamId === '') {
    return { ok: false, code: 'NOT_READY', message: 'This event has no stream yet.' };
  }

  const details = await ingestionDetails(env, config, streamId);
  if (!details.ok) return { ok: false, code: details.code, message: details.message };

  return {
    ok: true,
    data: {
      ingestion: {
        server_url: details.address,
        stream_key: details.streamName,
        stream_status: details.status,
      },
    },
  };
}

/** Statuses an audience has any business seeing. */
const AUDIENCE_STATUSES = ['SCHEDULED', 'READY', 'LIVE', 'COMPLETE'];

/**
 * The events this actor may see.
 *
 * Somebody who cannot run live events — a learner, an applicant — is shown
 * only events that are scheduled, running or finished. A draft nobody has
 * announced yet, a cancelled event, and one that failed to reach YouTube are
 * all internal states, and listing them would tell an audience about events
 * the academy has not decided to hold.
 */
export async function listLiveEvents(
  db: D1Database,
  params: URLSearchParams,
  manages: boolean,
): Promise<Record<string, unknown>[]> {
  const clauses: string[] = [];
  const binds: unknown[] = [];

  if (!manages) {
    clauses.push(
      `status IN (${AUDIENCE_STATUSES.map((_, index) => `?${index + 1}`).join(', ')})`,
    );
    binds.push(...AUDIENCE_STATUSES);
  }

  const status = str(params.get('status')).toUpperCase();
  if (status !== '' && (manages || AUDIENCE_STATUSES.includes(status))) {
    binds.push(status);
    clauses.push(`status = ?${binds.length}`);
  }

  const limit = Math.min(num(params.get('limit')) ?? 100, 200);
  const rows = await db
    .prepare(
      `SELECT * FROM youtube_live_events
        ${clauses.length === 0 ? '' : `WHERE ${clauses.join(' AND ')}`}
        ORDER BY CASE WHEN scheduled_start IS NULL THEN 1 ELSE 0 END,
                 scheduled_start DESC
        LIMIT ${limit}`,
    )
    .bind(...binds)
    .all();
  return rows.results.map((row) => liveEventToJson(row, manages));
}

/** Whether this event is one an audience may be shown at all. */
export const isAudienceVisible = (row: Record<string, unknown>) =>
  AUDIENCE_STATUSES.includes(str(row.status));

/**
 * One event as a client sees it.
 *
 * Never a stream key and never a broadcast credential: those are fetched
 * deliberately by an authorised admin from the ingestion route, not carried
 * along in every listing that happens to include this event.
 *
 * `last_error` and the broadcast id are for whoever is running the event.
 * A failure to reach YouTube is an operational detail, and showing it to an
 * audience explains nothing while revealing how the academy's plumbing works.
 */
export const liveEventToJson = (
  row: Record<string, unknown>,
  manages = false,
) => ({
  id: str(row.id),
  title: str(row.title),
  description: str(row.description),
  speaker: str(row.speaker),
  scheduled_start: row.scheduled_start ?? null,
  scheduled_end: row.scheduled_end ?? null,
  actual_start: row.actual_start ?? null,
  actual_end: row.actual_end ?? null,
  status: str(row.status),
  privacy_status: str(row.privacy_status),
  watch_url: str(row.watch_url),
  youtube_video_id: str(row.youtube_video_id),
  programme_id: row.programme_id ?? null,
  event_id: row.event_id ?? null,
  created_at: row.created_at ?? null,
  ...(manages
    ? {
        youtube_broadcast_id: str(row.youtube_broadcast_id),
        last_error: str(row.last_error),
      }
    : {}),
});

/** Cancels a scheduled event and removes the broadcast from YouTube. */
export async function cancelLiveEvent(
  env: YouTubeEnv,
  config: YouTubeConfig,
  id: string,
): Promise<LiveResult> {
  const row = await liveEventRow(env.WEA_DB, id);
  if (!row) return { ok: false, code: 'NOT_FOUND' };
  if (str(row.status) === 'LIVE') {
    return {
      ok: false,
      code: 'EVENT_IS_LIVE',
      message: 'End the event before cancelling it.',
    };
  }

  const broadcastId = str(row.youtube_broadcast_id);
  if (broadcastId !== '') {
    const result = await youtubeApi(env, config, '/liveBroadcasts', {
      method: 'DELETE',
      query: { id: broadcastId },
    });
    if (!result.ok && result.status !== 404) {
      return { ok: false, code: result.code, message: result.message };
    }
  }

  await env.WEA_DB.prepare(
    `UPDATE youtube_live_events
        SET status = 'CANCELLED', updated_at = CURRENT_TIMESTAMP
      WHERE id = ?1`,
  )
    .bind(id)
    .run();
  return { ok: true, data: { ok: true } };
}
