/**
 * Academy video: WUCO's record of what is on the channel, and who put it there.
 *
 * YouTube holds the file. This module holds everything YouTube does not know:
 * which module a lecture belongs to, which lecturer recorded it, whether the
 * academy considers it ready, and whether the person asking to change it is
 * allowed to.
 *
 * Ownership is enforced here rather than in the interface. A lecturer may
 * upload, and may manage what they uploaded; anything else is refused by
 * `mayManage`, so hiding the button in Flutter is a courtesy to the user and
 * not a security measure.
 */

import { newId } from './auth';
import { num, str } from './http';
import { Actor, can } from './permissions';
import {
  YouTubeConfig,
  YouTubeEnv,
  createUploadSession,
  watchUrlFor,
  youtubeApi,
} from './youtube';

export interface VideoResult {
  ok: boolean;
  code?: string;
  message?: string;
  data?: Record<string, unknown>;
}

const PRIVACY = ['PRIVATE', 'UNLISTED', 'PUBLIC'];

/** Video files YouTube accepts that a browser or phone will actually produce. */
const VIDEO_TYPES = [
  'video/mp4',
  'video/quicktime',
  'video/x-m4v',
  'video/webm',
  'video/x-matroska',
  'video/mpeg',
  'video/x-msvideo',
];

/** YouTube's own ceiling. Rejected here so a doomed upload never starts. */
const MAX_BYTES = 256 * 1024 * 1024 * 1024;

/**
 * Whether this actor may change this video.
 *
 * `video.manage.all` is the right to touch anybody's; without it, an uploader
 * may still manage their own. Written as one function because "own videos
 * only" is a rule that has to hold identically at every route that edits or
 * deletes, and repeating it per handler is how one of them ends up different.
 */
export function mayManage(actor: Actor | null, row: Record<string, unknown>): boolean {
  if (!actor) return false;
  if (can(actor, 'video.manage.all')) return true;
  return can(actor, 'video.upload') && str(row.uploaded_by) === actor.id;
}

/**
 * Registers a video and opens its upload session.
 *
 * The row is written *before* Google is asked for anything, so an upload that
 * dies half way leaves a record the uploader can see and retry rather than
 * nothing at all. It stays `UPLOADING` until the client reports the bytes are
 * in and the video id is confirmed against YouTube.
 */
export async function beginVideoUpload(
  env: YouTubeEnv,
  config: YouTubeConfig,
  actor: Actor,
  body: Record<string, unknown>,
): Promise<VideoResult> {
  const title = str(body.title);
  if (title === '') {
    return { ok: false, code: 'INVALID_REQUEST', message: 'A title is required.' };
  }

  const contentType = str(body.content_type).toLowerCase();
  if (!VIDEO_TYPES.includes(contentType)) {
    return {
      ok: false,
      code: 'UNSUPPORTED_TYPE',
      message: 'Upload an MP4, MOV, WebM, MKV, MPEG or AVI file.',
    };
  }

  const sizeBytes = num(body.size_bytes) ?? 0;
  if (sizeBytes <= 0) {
    return { ok: false, code: 'INVALID_REQUEST', message: 'The file size is required.' };
  }
  if (sizeBytes > MAX_BYTES) {
    return {
      ok: false,
      code: 'FILE_TOO_LARGE',
      message: 'YouTube accepts files up to 256 GB.',
    };
  }

  // Anything not recognised is treated as private rather than as public: a
  // wrong guess in that direction is a video nobody can see, not a video
  // everybody can.
  const requested = str(body.privacy_status).toUpperCase();
  const privacy = PRIVACY.includes(requested) ? requested : 'PRIVATE';

  const session = await createUploadSession(
    env,
    config,
    {
      title,
      description: str(body.description),
      privacyStatus: privacy,
      categoryId: str(body.category_id) || undefined,
    },
    { contentType, sizeBytes },
  );
  if (!session.ok) {
    return { ok: false, code: session.code, message: session.message };
  }

  const id = `vid-${newId()}`;
  await env.WEA_DB.prepare(
    `INSERT INTO youtube_videos
       (id, title, description, programme_id, module_id, lesson_id, category,
        privacy_status, status, uploaded_by, uploaded_by_role)
     VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, 'UPLOADING', ?9, ?10)`,
  )
    .bind(
      id,
      title,
      str(body.description),
      str(body.programme_id) || null,
      str(body.module_id) || null,
      str(body.lesson_id) || null,
      str(body.category),
      privacy,
      actor.id,
      actor.role,
    )
    .run();

  return {
    ok: true,
    data: {
      video: { id, title, status: 'UPLOADING', privacy_status: privacy },
      // Sent to the client so the file goes straight to Google. It authorises
      // this one upload and nothing else, and it expires on its own.
      upload_url: session.uploadUrl,
    },
  };
}

/**
 * Confirms an upload finished, by asking YouTube rather than believing the
 * client.
 *
 * The client reports the video id Google gave it, and WUCO checks that the id
 * exists and what state it is in. A client that reported a video id it did not
 * upload would otherwise be able to attach any video on YouTube to an academy
 * lesson.
 */
export async function completeVideoUpload(
  env: YouTubeEnv,
  config: YouTubeConfig,
  actor: Actor,
  id: string,
  youtubeVideoId: string,
): Promise<VideoResult> {
  const row = await env.WEA_DB.prepare('SELECT * FROM youtube_videos WHERE id = ?1')
    .bind(id)
    .first<Record<string, unknown>>();
  if (!row) return { ok: false, code: 'NOT_FOUND' };
  if (!mayManage(actor, row)) return { ok: false, code: 'FORBIDDEN' };

  const videoId = str(youtubeVideoId);
  if (videoId === '') {
    return { ok: false, code: 'INVALID_REQUEST', message: 'The YouTube video id is required.' };
  }

  const result = await youtubeApi<{
    items?: {
      status?: { uploadStatus?: string; privacyStatus?: string; rejectionReason?: string };
      contentDetails?: { duration?: string };
      snippet?: { thumbnails?: Record<string, { url?: string }> };
    }[];
  }>(env, config, '/videos', {
    method: 'GET',
    query: { part: 'status,contentDetails,snippet', id: videoId },
  });
  if (!result.ok) return { ok: false, code: result.code, message: result.message };

  const item = result.data.items?.[0];
  if (!item) {
    await env.WEA_DB.prepare(
      `UPDATE youtube_videos
          SET status = 'FAILED', failure_reason = ?1, updated_at = CURRENT_TIMESTAMP
        WHERE id = ?2`,
    )
      .bind('YouTube has no video with that id.', id)
      .run();
    return {
      ok: false,
      code: 'YOUTUBE_VIDEO_NOT_FOUND',
      message: 'YouTube has no video with that id.',
    };
  }

  const uploadStatus = str(item.status?.uploadStatus);
  const rejection = str(item.status?.rejectionReason);
  // `processed` is ready; `uploaded` means YouTube still has work to do.
  const status =
    uploadStatus === 'processed'
      ? 'READY'
      : uploadStatus === 'rejected' || uploadStatus === 'failed'
        ? 'FAILED'
        : 'PROCESSING';

  await env.WEA_DB.prepare(
    `UPDATE youtube_videos
        SET youtube_video_id = ?1, status = ?2, youtube_status = ?3,
            failure_reason = ?4, duration_seconds = ?5, thumbnail_url = ?6,
            privacy_status = ?7, updated_at = CURRENT_TIMESTAMP
      WHERE id = ?8`,
  )
    .bind(
      videoId,
      status,
      uploadStatus,
      rejection,
      isoDurationToSeconds(str(item.contentDetails?.duration)),
      str(item.snippet?.thumbnails?.high?.url ?? item.snippet?.thumbnails?.default?.url),
      // What YouTube actually applied, which for an unaudited API project is
      // private whatever was asked for.
      str(item.status?.privacyStatus).toUpperCase() || 'PRIVATE',
      id,
    )
    .run();

  return {
    ok: true,
    data: {
      video: {
        id,
        youtube_video_id: videoId,
        status,
        youtube_status: uploadStatus,
        url: watchUrlFor(videoId),
      },
    },
  };
}

/** `PT1H2M3S` as plain seconds. Zero when YouTube has not decided yet. */
export function isoDurationToSeconds(duration: string): number {
  const match = duration.match(/^PT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?$/);
  if (!match) return 0;
  const [, hours, minutes, seconds] = match;
  return Number(hours ?? 0) * 3600 + Number(minutes ?? 0) * 60 + Number(seconds ?? 0);
}

/**
 * The videos this actor may see.
 *
 * An uploader without `video.manage.all` is shown their own, which is the same
 * rule the write path enforces — a list that showed more than it allowed to be
 * edited would only be a way of learning what else exists.
 */
export async function listVideos(
  db: D1Database,
  actor: Actor,
  params: URLSearchParams,
): Promise<Record<string, unknown>[]> {
  const clauses = ["status != 'DELETED'"];
  const binds: unknown[] = [];

  if (!can(actor, 'video.manage.all')) {
    binds.push(actor.id);
    clauses.push(`uploaded_by = ?${binds.length}`);
  }
  for (const [param, column] of [
    ['programme_id', 'programme_id'],
    ['module_id', 'module_id'],
    ['lesson_id', 'lesson_id'],
    ['status', 'status'],
  ] as const) {
    const value = str(params.get(param));
    if (value !== '') {
      binds.push(value);
      clauses.push(`${column} = ?${binds.length}`);
    }
  }

  const limit = Math.min(num(params.get('limit')) ?? 100, 200);
  const rows = await db
    .prepare(
      `SELECT * FROM youtube_videos
        WHERE ${clauses.join(' AND ')}
        ORDER BY created_at DESC
        LIMIT ${limit}`,
    )
    .bind(...binds)
    .all();
  return rows.results.map(videoToJson);
}

export const videoToJson = (row: Record<string, unknown>) => ({
  id: str(row.id),
  youtube_video_id: str(row.youtube_video_id),
  url: str(row.youtube_video_id) === '' ? '' : watchUrlFor(str(row.youtube_video_id)),
  title: str(row.title),
  description: str(row.description),
  programme_id: row.programme_id ?? null,
  module_id: row.module_id ?? null,
  lesson_id: row.lesson_id ?? null,
  category: str(row.category),
  privacy_status: str(row.privacy_status),
  status: str(row.status),
  youtube_status: str(row.youtube_status),
  failure_reason: str(row.failure_reason),
  duration_seconds: num(row.duration_seconds) ?? 0,
  thumbnail_url: str(row.thumbnail_url),
  uploaded_by: row.uploaded_by ?? null,
  created_at: row.created_at ?? null,
});

/** Editable fields. Deliberately not the uploader, the status or the ids. */
export async function updateVideo(
  env: YouTubeEnv,
  config: YouTubeConfig,
  actor: Actor,
  id: string,
  body: Record<string, unknown>,
): Promise<VideoResult> {
  const row = await env.WEA_DB.prepare('SELECT * FROM youtube_videos WHERE id = ?1')
    .bind(id)
    .first<Record<string, unknown>>();
  if (!row) return { ok: false, code: 'NOT_FOUND' };
  if (!mayManage(actor, row)) return { ok: false, code: 'FORBIDDEN' };

  const title = str(body.title) || str(row.title);
  const description =
    body.description === undefined ? str(row.description) : str(body.description);
  const requested = str(body.privacy_status).toUpperCase();
  const privacy = PRIVACY.includes(requested) ? requested : str(row.privacy_status);

  // Title, description and visibility live on YouTube as well as here. Google
  // is updated first: a WUCO row claiming a video is unlisted while YouTube
  // still has it public would be a lie in the direction that matters.
  if (str(row.youtube_video_id) !== '') {
    const result = await youtubeApi(env, config, '/videos', {
      method: 'PUT',
      query: { part: 'snippet,status' },
      body: JSON.stringify({
        id: str(row.youtube_video_id),
        snippet: {
          title: title.slice(0, 100),
          description: description.slice(0, 5000),
          categoryId: str(row.category) || '27',
        },
        status: { privacyStatus: privacy.toLowerCase() },
      }),
    });
    if (!result.ok) return { ok: false, code: result.code, message: result.message };
  }

  await env.WEA_DB.prepare(
    `UPDATE youtube_videos
        SET title = ?1, description = ?2, privacy_status = ?3,
            programme_id = ?4, module_id = ?5, lesson_id = ?6,
            updated_at = CURRENT_TIMESTAMP
      WHERE id = ?7`,
  )
    .bind(
      title,
      description,
      privacy,
      body.programme_id === undefined ? row.programme_id ?? null : str(body.programme_id) || null,
      body.module_id === undefined ? row.module_id ?? null : str(body.module_id) || null,
      body.lesson_id === undefined ? row.lesson_id ?? null : str(body.lesson_id) || null,
      id,
    )
    .run();

  const updated = await env.WEA_DB.prepare('SELECT * FROM youtube_videos WHERE id = ?1')
    .bind(id)
    .first<Record<string, unknown>>();
  return { ok: true, data: { video: videoToJson(updated ?? {}) } };
}

/**
 * Removes a video from YouTube and marks the row deleted.
 *
 * The row is kept rather than dropped so that a lesson still referring to it
 * shows something explicable, and so the academy retains the record that the
 * video existed and who removed it.
 */
export async function deleteVideo(
  env: YouTubeEnv,
  config: YouTubeConfig,
  actor: Actor,
  id: string,
): Promise<VideoResult> {
  const row = await env.WEA_DB.prepare('SELECT * FROM youtube_videos WHERE id = ?1')
    .bind(id)
    .first<Record<string, unknown>>();
  if (!row) return { ok: false, code: 'NOT_FOUND' };
  if (!mayManage(actor, row)) return { ok: false, code: 'FORBIDDEN' };

  if (str(row.youtube_video_id) !== '') {
    const result = await youtubeApi(env, config, '/videos', {
      method: 'DELETE',
      query: { id: str(row.youtube_video_id) },
    });
    // A video already gone from YouTube is the state being asked for, so a
    // 404 is a success here rather than something to refuse.
    if (!result.ok && result.status !== 404) {
      return { ok: false, code: result.code, message: result.message };
    }
  }

  await env.WEA_DB.prepare(
    `UPDATE youtube_videos
        SET status = 'DELETED', updated_at = CURRENT_TIMESTAMP
      WHERE id = ?1`,
  )
    .bind(id)
    .run();
  return { ok: true, data: { ok: true } };
}
