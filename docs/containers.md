# Containers & CI

## Local build

```bash
docker build -t videor:local .
docker run --rm -p 3000:80 \
  -e RAILS_MASTER_KEY=$(cat config/master.key) \
  -e DATABASE_URL=sqlite3:///rails/storage/production.sqlite3 \
  -e REDIS_URL=redis://host.docker.internal:6379/0 \
  -e AWS_ACCESS_KEY_ID=... \
  -e AWS_SECRET_ACCESS_KEY=... \
  -e VIDEO_JOBS_BUCKET=... \
  -e STORAGE_HOST_ALLOWLIST=download.example.com \
  videor:local
```

The image installs ffmpeg so `VideoJobProcessorJob` can run without additional packages. Tailwind assets are precompiled during the build (`rails assets:precompile`).

## GitHub Actions publish

`.github/workflows/docker-image.yml` builds and pushes the container to GHCR:

- Triggers on pushes to `main`, tags starting with `v`, or manual `workflow_dispatch`.
- Tags include `latest` (for main), the git SHA, and the tag name.
- Uses the repo’s `GITHUB_TOKEN` to authenticate against `ghcr.io/<owner>/<repo>`.

Images land in the “Packages” section of the repo. Reference them as `ghcr.io/<owner>/<repo>:<tag>` when deploying (e.g., through Kamal or Kubernetes).

## docker compose for local dev

`docker-compose.yml` now includes `app` (Rails server) and `worker` (Sidekiq) services on top of Redis + MinIO. To run everything in containers:

```bash
cp .env.compose.example .env.compose
# edit .env.compose with real secrets (master key, S3 creds, bucket name, etc.)
docker compose up --build
```

The compose file mounts the repo into `/rails` so code changes hot-reload. Tailwind watcher is not started inside the container by default, so if you edit Tailwind CSS classes run `mise exec -- bin/rails tailwindcss:build` on the host (or add another compose service). Redis is exposed on `6379`, MinIO console on `9001`, and the Rails server on `3000`.

## K3s manifests

The `k8s/` directory contains basic YAML manifests for a web deployment, Sidekiq worker, and Redis service. Steps:

1. Update `k8s/deployment.yml` with your registry image (`ghcr.io/<owner>/<repo>:<tag>`) and download host.
2. Create a secret manifest (or use `kubectl create secret generic videor-secrets --from-literal=...`) with `RAILS_MASTER_KEY`, DB URL, Redis URL, AWS credentials, `VIDEO_JOBS_BUCKET`, etc.
3. Apply resources:
   ```bash
   kubectl apply -f k8s/redis.yml
   kubectl apply -f k8s/deployment.yml
   ```
4. Add your ingress of choice (Traefik in k3s) with a rule pointing to the `videor-web` service.

For a more configurable setup, use the Helm chart in `chart/` (see below).

## Helm chart

The `chart/` directory contains a basic Helm chart that deploys the web app, Sidekiq worker, and (optionally) Redis. To install:

```bash
helm install videor ./chart \
  --set image.repository=ghcr.io/<owner>/<repo> \
  --set image.tag=<tag> \
  --set secrets.railsMasterKey=$(cat config/master.key) \
  --set secrets.awsAccessKeyId=... \
  --set secrets.awsSecretAccessKey=... \
  --set secrets.videoJobsBucket=... \
  --set secrets.databaseUrl=postgres://user:pass@host:5432/videor_production \
  --set env.STORAGE_HOST_ALLOWLIST=download.example.com
```

Adjust `values.yaml` or pass overrides for replica counts, Redis settings, etc. If you already run Redis externally, set `redis.enabled=false` and point `env.REDIS_URL` at your service.

### On-prem helper script

For simple on-prem builds, copy `.deploy.env.example` to `.deploy.env`, fill in registry/secrets, then run:

```bash
scripts/deploy_onprem.sh
```

The script builds & pushes the Docker image and executes `helm upgrade --install` using the provided values. Set `KUBE_CONTEXT` inside `.deploy.env` if you need to target a specific kubeconfig context.

## Runtime configuration

The container expects the same environment variables documented in `docs/development.md` (database, Redis, storage credentials, etc.). When running with Kamal or in CI, be sure to provide:

- `RAILS_MASTER_KEY`
- `DATABASE_URL`
- `REDIS_URL`
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION`
- `VIDEO_JOBS_BUCKET` + optional `S3_ENDPOINT`
- `STORAGE_HOST_ALLOWLIST`
