# Cloudflare deployment

This repository uses two GitHub-driven Cloudflare deployments:

- **Cloudflare Pages** builds and serves the Flutter web frontend whenever `main` changes.
- **Cloudflare Workers + D1** deploy through GitHub Actions whenever `main` changes under `cloudflare/`.

## One-time Cloudflare setup

### 1. Create the D1 database

From `cloudflare/`, authenticate and create the production database:

```bash
npx wrangler login
npx wrangler d1 create wuco-production --binding WEA_DB --update-config
```

The command replaces `REPLACE_WITH_D1_DATABASE_ID` in [cloudflare/wrangler.jsonc](cloudflare/wrangler.jsonc). Do not commit credentials.

### 2. Create and connect the Pages project

In **Cloudflare Dashboard → Workers & Pages → Create → Pages → Connect to Git**:

- Repository: `dawillcomputers/wuco`
- Production branch: `main`
- Framework preset: `None`
- Build command: `bash scripts/build-cloudflare-pages.sh`
- Build output directory: `build/web`

Cloudflare Pages then deploys each push to `main` and creates previews for pull requests. Its production domain begins as `https://wuco.pages.dev`.

### 3. Configure the Worker origin

If Cloudflare assigns a different Pages domain or a custom domain is used, change `ALLOWED_ORIGIN` in [cloudflare/wrangler.jsonc](cloudflare/wrangler.jsonc) before the first API deployment.

### 4. Add GitHub deployment secrets

In **GitHub → Settings → Secrets and variables → Actions**, add:

- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_API_TOKEN`

Create a least-privilege Cloudflare API token scoped to this account with Worker deployment and D1 permissions. Never store it in the repository.

After those values are in place, every push to `main` applies unapplied D1 migrations first and then deploys `wuco-api`.

## Local verification

```bash
cd cloudflare
npm install
npm run db:migrate:local
npm run dev
```

The Worker health endpoint is available at `/api/health`.
