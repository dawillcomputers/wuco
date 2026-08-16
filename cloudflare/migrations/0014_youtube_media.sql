-- WUCO video and live streaming, carried on the academy's YouTube channel.
--
-- YouTube stores and serves the video; WUCO decides who may put something
-- there, what it belongs to, and who may put it in front of an audience. This
-- schema is the WUCO half of that: every row here points at something on
-- YouTube rather than containing it.
--
-- No credential is stored in this file's tables. Not the refresh token, not
-- an access token, not a stream key. Those live in KV (WUCO_TOKENS), which is
-- reached only by the Worker, and the stream key is never persisted at all —
-- it is fetched from YouTube when an authorised admin asks for it. A database
-- export is a routine thing to have; it must not be a set of keys to the
-- academy's channel.

-- --------------------------------------------------------------------------
-- The channel connection
-- --------------------------------------------------------------------------

-- Which YouTube channel WUCO is connected to, and who connected it.
--
-- One row, id 'primary'. The academy has one channel, and making that a
-- constraint rather than a convention means no upload can quietly land on a
-- second one somebody connected by accident.
CREATE TABLE IF NOT EXISTS youtube_connections (
  id TEXT PRIMARY KEY NOT NULL DEFAULT 'primary',
  channel_id TEXT NOT NULL DEFAULT '',
  channel_title TEXT NOT NULL DEFAULT '',
  -- Scopes Google actually granted, which can be fewer than were asked for.
  -- Recorded so a capability that is missing can be named, rather than
  -- discovered as a 403 in the middle of a live event.
  granted_scopes TEXT NOT NULL DEFAULT '',
  -- When the access token in KV expires. Not the token, only its clock, so
  -- the refresh can be scheduled without reading the secret.
  token_expires_at TEXT,
  connected_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  connected_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  -- Set when Google refuses the refresh token: revoked in the Google account,
  -- password changed, consent withdrawn. Surfaced so the academy is told to
  -- reconnect instead of watching uploads fail.
  disconnected_at TEXT,
  last_error TEXT NOT NULL DEFAULT '',
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- --------------------------------------------------------------------------
-- Videos
-- --------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS youtube_videos (
  id TEXT PRIMARY KEY NOT NULL,
  -- Empty until YouTube has accepted the upload. A row exists before that so
  -- an upload that fails half way is visible and retryable rather than lost.
  youtube_video_id TEXT NOT NULL DEFAULT '',
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',

  -- Where this sits in the curriculum. All optional: a video may be a
  -- standalone piece of academy media belonging to no programme at all.
  programme_id TEXT REFERENCES programmes(id) ON DELETE SET NULL,
  module_id TEXT REFERENCES programme_modules(id) ON DELETE SET NULL,
  lesson_id TEXT REFERENCES programme_lessons(id) ON DELETE SET NULL,
  category TEXT NOT NULL DEFAULT '',

  -- PRIVATE until somebody deliberately publishes.
  --
  -- Google restricts uploads made through the API by projects that have not
  -- passed its audit to private viewing, whatever is asked for. Defaulting to
  -- private means WUCO's own record matches what YouTube actually did, rather
  -- than claiming a video is public when nobody outside can see it.
  privacy_status TEXT NOT NULL DEFAULT 'PRIVATE'
    CHECK (privacy_status IN ('PRIVATE', 'UNLISTED', 'PUBLIC')),

  -- Where this row is in its own life, which is not the same question as what
  -- YouTube thinks of the file.
  status TEXT NOT NULL DEFAULT 'DRAFT'
    CHECK (status IN ('DRAFT', 'UPLOADING', 'PROCESSING', 'READY', 'FAILED', 'DELETED')),
  -- YouTube's own verdict: uploaded, processed, rejected, failed. Copied from
  -- the API rather than inferred, so a rejection reason can be shown as given.
  youtube_status TEXT NOT NULL DEFAULT '',
  failure_reason TEXT NOT NULL DEFAULT '',

  duration_seconds INTEGER NOT NULL DEFAULT 0,
  thumbnail_url TEXT NOT NULL DEFAULT '',

  -- Who put it there. The role is kept alongside the id because it is the
  -- answer to "was this person allowed to?" at the time, and a later role
  -- change must not rewrite that history.
  uploaded_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  uploaded_by_role TEXT NOT NULL DEFAULT '',

  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_youtube_videos_owner
  ON youtube_videos (uploaded_by, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_youtube_videos_lesson
  ON youtube_videos (lesson_id);
CREATE INDEX IF NOT EXISTS idx_youtube_videos_status
  ON youtube_videos (status, created_at DESC);

-- --------------------------------------------------------------------------
-- Live events
-- --------------------------------------------------------------------------

-- A WUCO live event, and the YouTube broadcast that carries it.
--
-- YouTube separates the *broadcast* (the thing an audience watches, with a
-- title and a scheduled time) from the *stream* (the ingest endpoint an
-- encoder pushes video into). A broadcast shows nothing until a stream is
-- bound to it and something is actually being sent. Both ids are kept so WUCO
-- can drive the broadcast without ever having to guess which stream it is on.
CREATE TABLE IF NOT EXISTS youtube_live_events (
  id TEXT PRIMARY KEY NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  speaker TEXT NOT NULL DEFAULT '',

  scheduled_start TEXT,
  scheduled_end TEXT,
  actual_start TEXT,
  actual_end TEXT,

  youtube_broadcast_id TEXT NOT NULL DEFAULT '',
  youtube_stream_id TEXT NOT NULL DEFAULT '',
  -- The broadcast's own video id, watchable after the event ends.
  youtube_video_id TEXT NOT NULL DEFAULT '',
  watch_url TEXT NOT NULL DEFAULT '',

  privacy_status TEXT NOT NULL DEFAULT 'UNLISTED'
    CHECK (privacy_status IN ('PRIVATE', 'UNLISTED', 'PUBLIC')),

  -- WUCO's view of the event. `LIVE` is only ever set by the Worker after
  -- YouTube has confirmed the transition, never optimistically on a click:
  -- telling an audience an event is live when it is not is the one failure
  -- this system exists to avoid.
  status TEXT NOT NULL DEFAULT 'DRAFT'
    CHECK (status IN ('DRAFT', 'SCHEDULED', 'READY', 'LIVE', 'COMPLETE', 'CANCELLED', 'FAILED')),
  last_error TEXT NOT NULL DEFAULT '',

  -- Optionally tied to the rest of the academy.
  programme_id TEXT REFERENCES programmes(id) ON DELETE SET NULL,
  event_id TEXT REFERENCES events(id) ON DELETE SET NULL,

  created_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  created_by_role TEXT NOT NULL DEFAULT '',
  -- Who put it on air, and who took it off. Kept separately from the creator:
  -- these are the two actions that change what the public can see.
  started_by TEXT REFERENCES users(id) ON DELETE SET NULL,
  ended_by TEXT REFERENCES users(id) ON DELETE SET NULL,

  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_youtube_live_status
  ON youtube_live_events (status, scheduled_start);
CREATE INDEX IF NOT EXISTS idx_youtube_live_start
  ON youtube_live_events (scheduled_start DESC);
