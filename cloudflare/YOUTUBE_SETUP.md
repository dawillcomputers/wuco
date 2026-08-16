# Connecting WUCO to YouTube

Everything the Worker needs before the YouTube features work, in the order it
has to happen. Each step says *why*, because most of these are only obvious
once you have got them wrong.

The code is finished and verified (`npm run verify:youtube`). What remains is
configuration, and configuration is where this integration is easy to break.

---

## 1. Create the KV namespace

The refresh token, the cached access token, and single-use OAuth states live in
KV — never in D1. A database export is a routine thing for an academy to hold;
a set of keys to its YouTube channel is not.

```bash
cd cloudflare
npx wrangler kv namespace create WUCO_TOKENS
npx wrangler kv namespace create WUCO_TOKENS --preview
```

Paste both ids into `wrangler.jsonc`, replacing `REPLACE_WITH_KV_NAMESPACE_ID`
and `REPLACE_WITH_KV_PREVIEW_ID`.

## 2. Decide the Worker's public URL

You need it before the Google client, because Google compares the redirect URI
as a **literal string** — scheme, host, path and trailing slash all have to
match, or consent fails with `redirect_uri_mismatch`.

If the Worker is on `workers.dev`, find the host with:

```bash
npx wrangler deploy --dry-run
```

The redirect URI is that host plus `/api/auth/youtube/callback`, e.g.

```
https://wuco-api.<your-subdomain>.workers.dev/api/auth/youtube/callback
```

A custom domain is worth setting up first if you intend to use one, because
changing it later means editing it in two places that must agree.

## 3. Create the Google OAuth client

In **Google Cloud → APIs & Services → Credentials → Create Credentials → OAuth
client ID**:

- Application type: **Web application**
- Name: `WUCO Executive Academy Backend`
- Authorised redirect URI: the exact string from step 2

Enable both APIs on the project if they are not already on:

- **YouTube Data API v3** — uploads, video metadata
- **YouTube Live Streaming API** — broadcasts and streams

On the OAuth consent screen, add the account that owns the WUCO channel as a
**test user** while the project is unverified, or consent will be refused.

> The YouTube Live API does not accept service accounts. That is why there is a
> human consent step at all, and why it has to be done by someone who can act
> for the channel.

## 4. Set the Worker configuration

Two of the three values are **not** secrets. The client id and the redirect URI
both travel in the browser's address bar during consent, so they live in
`wrangler.jsonc` where they can be reviewed in version control. Only the client
secret is hidden.

All wrangler commands must run from the `cloudflare` directory — that is where
`wrangler.jsonc` is. Run them from the repository root and wrangler reports
`Required Worker name missing`, because it found no configuration.

In `wrangler.jsonc` under `vars`:

```jsonc
"GOOGLE_REDIRECT_URI": "https://<worker-host>/api/auth/youtube/callback",
"GOOGLE_CLIENT_ID": "123456789-abc.apps.googleusercontent.com"
```

Then the secret, which prompts for the value:

```bash
cd cloudflare
npx wrangler secret put GOOGLE_CLIENT_SECRET
npx wrangler deploy
```

### One client or two

`GOOGLE_CLIENT_ID` is also what Google **sign-in** verifies its ID tokens
against. If the same Google client does both jobs, set only the `GOOGLE_*`
values and stop here.

If you made a separate client for YouTube — which is tidier, since acting on a
channel needs a confidential client with a secret and signing people in does
not — set the YouTube pair instead. They win where present, and sign-in keeps
its own:

```jsonc
"YOUTUBE_CLIENT_ID": "987654321-xyz.apps.googleusercontent.com"
```

```bash
npx wrangler secret put YOUTUBE_CLIENT_SECRET
```

Optionally set `ADMIN_SITE_URL` to control where the callback page's "Back to
WUCO" link points.

Never put a client secret, or any token, in the Flutter app. Anything shipped
to a client is readable by anyone who has the app.

## 5. Apply the migration

```bash
npx wrangler d1 migrations apply WEA_DB --local    # test first
npx wrangler d1 migrations apply WEA_DB --remote
```

## 6. Connect the channel

Signed in as the **owner** (this is `platform.integrations`, which no other
role holds):

```
POST /api/youtube/connect   →  { "authorisation_url": "https://accounts.google.com/..." }
```

Open that URL, choose the account that owns the WUCO channel, allow. Google
returns to the callback, which shows a page naming the channel it connected —
check it. An owner with several Google accounts can authorise the wrong one,
and the channel name is how you find out now rather than after uploading.

Confirm with `GET /api/youtube/status`.

---

## What to expect from YouTube itself

**Uploads will be private at first.** Google restricts videos uploaded through
the API by projects that have not passed its audit to private viewing —
whatever privacy you ask for. This is not a bug in WUCO, and the code reflects
it: uploads default to `PRIVATE`, and the video's recorded privacy is set to
what YouTube *actually applied*, not what was requested.

To publish publicly, apply for an API audit in the Google Cloud console. Until
then, unlisted-by-link sharing and private review both work normally.

**Quota.** The Data API allows 10,000 units/day by default. An upload costs
~1,600 units, so roughly **6 uploads per day** before the quota is exhausted.
This is the constraint most likely to surprise you in practice. Request a
quota increase if the academy will upload in volume.

---

## How live events actually work

The part worth being clear about before an audience is watching:

```
Create event  →  YouTube broadcast + stream created and bound   (WUCO does this)
Configure encoder with the ingest address and key               (an admin does this)
Encoder starts sending video                                    (OBS / hardware)
Start live    →  broadcast transitions to live                  (WUCO does this)
```

**"Start live" is not a camera button.** It transitions a broadcast that
already has video arriving at it. The video comes from an encoder — OBS or a
hardware unit — pointed at the ingest address from:

```
GET /api/live/{id}/ingestion   →  { server_url, stream_key, stream_status }
```

That stream key is a credential that lets anything broadcast to the academy's
channel. It is fetched from YouTube on demand and **never stored** — it belongs
in an encoder's settings box, not in WUCO's database.

`POST /api/live/{id}/start` refuses with `STREAM_NOT_ACTIVE` if YouTube is not
receiving video yet. That refusal is deliberate: YouTube will happily accept a
transition for a broadcast whose encoder is not connected, and the result is a
live event showing a black screen to everyone who was invited.

---

## Why uploads do not pass through the Worker

A YouTube video may be up to 256 GB. A Worker has a fraction of that in memory
and a request-size ceiling far below it, so proxying the file would cap WUCO's
uploads at roughly the size of a slide deck, and would bill Worker time in
proportion to every gigabyte the academy ever publishes.

Google's resumable upload protocol is built for this:

```
POST /api/videos/upload   →  { video: {...}, upload_url: "https://..." }
```

WUCO authenticates and describes the video; Google issues a one-shot session
URL; the client sends the bytes straight to Google. What the client receives
authorises **that upload and nothing else** — not another upload, not a read of
the channel, and nothing at all once the session expires. The access token
never leaves the Worker.

A resumable session also survives a dropped connection, which matters when a
lecturer is uploading a lecture over an unreliable line.

The client then reports the id Google gave it:

```
POST /api/videos/{id}/complete   { "youtube_video_id": "..." }
```

WUCO verifies that id against YouTube rather than believing it — otherwise a
client could attach any video on YouTube to an academy lesson.

---

## The API

Permission in brackets. Every one of these is enforced in the Worker; hiding a
button in Flutter is a courtesy to the user, not a security measure.

| Endpoint | Permission |
|---|---|
| `POST /api/youtube/connect` | `platform.integrations` (owner) |
| `GET /api/auth/youtube/callback` | public, protected by single-use `state` |
| `GET /api/youtube/status` | `platform.integrations` |
| `POST /api/youtube/disconnect` | `platform.integrations` |
| `GET /api/youtube/channel` | `platform.integrations` |
| `POST /api/videos/upload` | `video.upload` |
| `POST /api/videos/{id}/complete` | own video, or `video.manage.all` |
| `GET /api/videos` | `video.upload` (own only without `video.manage.all`) |
| `GET·PATCH·DELETE /api/videos/{id}` | own video, or `video.manage.all` |
| `POST /api/live` | `live.create` |
| `GET /api/live` | `live.create` or `catalogue.read` |
| `GET /api/live/{id}` | `live.create` or `catalogue.read` |
| `GET /api/live/{id}/status` | `live.create` |
| `GET /api/live/{id}/ingestion` | `live.control` |
| `POST /api/live/{id}/start` | `live.control` |
| `POST /api/live/{id}/end` | `live.control` |
| `POST /api/live/{id}/cancel` | `live.create` |

Roles, from `permissions.ts`:

| | upload | manage all videos | create live | start/end live | connect channel |
|---|---|---|---|---|---|
| Lecturer | yes | no — own only | no | no | no |
| Admin | yes | yes | yes | yes | no |
| Super Admin | yes | yes | yes | yes | no |
| Owner | yes | yes | yes | yes | yes |

Creating an event and putting it on air are separate permissions because they
are separate risks: scheduling is reversible, and transitioning to live is what
an audience sees.
