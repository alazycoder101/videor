# Videor – Agent Guide

Welcome! This document keeps future AI contributors aligned on how to work inside this repo.

## Mission & Architecture
- HTML-first Rails 8.1 app using Turbo, Stimulus, and Tailwind (v4) for UI.
- Video jobs are stored in `VideoJob` records and processed asynchronously by `VideoJobProcessorJob` via Sidekiq.
- Upload flow is direct-to-S3/MinIO via `Uploads::PresignsController` + `StorageClient`. Only `/uploads/presign` and `/video_jobs/:id/status` need JSON/partial endpoints; everything else stays server-rendered.
- Live updates happen through Turbo Stream broadcasts sourced from `VideoJob` model callbacks. Stimulus `status-poll` offers a fallback.

## Tooling Rules
- **Always run commands through `mise exec -- …`** so we stay on Ruby 4.0.0 + Node LTS defined in `mise.toml`.
- Key commands:
  - `mise exec -- bundle install`
  - `mise exec -- bin/rails db:prepare`
  - `mise exec -- bin/dev` (foreman runs web, tailwind watcher, and sidekiq in Procfile.dev)
  - `mise exec -- bin/rails test`
- Redis (for Sidekiq) and MinIO live in `docker-compose.yml`. Run `docker compose up redis minio` before kicking off background work locally.
- FFmpeg must be installed on the worker image/container; the processor job shells out to the `ffmpeg` binary.

## Conventions & Tips
- Keep authentication cookie-based via `current_client_id` in `ApplicationController`.
- `StorageClient` is the single integration point with S3/MinIO. Extend it instead of rolling new client code.
- Stimulus controllers live in `app/javascript/controllers/`. Add controllers there and let `controllers/index.js` auto-load them.
- Prefer Turbo Streams for realtime updates; only fall back to the polling controller if absolutely necessary.
- Tests currently live under `test/` (MiniTest). Add coverage when touching non-trivial business logic.

## Documentation
- See `docs/development.md` for local setup details, environment variables, and workflows.
- Update both this file and the development doc whenever you add new workflows or conventions so other agents (and humans!) stay unblocked.
