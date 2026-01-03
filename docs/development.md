# Development Guide

## Toolchain
- We pin tooling through [`mise.toml`](../mise.toml):
  - Ruby `4.0.0`
  - Node.js `lts`
- Install once via `mise install`. Then prefix every command with `mise exec -- …` so the right tool versions are used (e.g. `mise exec -- bundle install`).

## First-time setup
1. Install dependencies: `mise exec -- bundle install`.
2. Prepare the database: `mise exec -- bin/rails db:prepare`.
3. Copy credentials or set your own `config/credentials.yml.enc`/`config/master.key`.
4. Provision infrastructure (Redis + MinIO) locally:
   ```bash
   docker compose up redis minio
   ```

## Running the app
- `mise exec -- bin/dev` runs the Rails server, Tailwind watcher, and Sidekiq worker through Foreman (`Procfile.dev`).
- If you prefer separate terminals:
  - `mise exec -- bin/rails server`
  - `mise exec -- bin/rails tailwindcss:watch`
  - `mise exec -- bundle exec sidekiq`

## Background processing
- Active Job is configured for Sidekiq (`config/application.rb`).
- Ensure `REDIS_URL` points at a Redis instance (default `redis://localhost:6379/0`).
- Workers rely on FFmpeg being available on `$PATH`.

## Storage configuration
Set these env vars (include them in `.env` or your process manager):

| Variable | Purpose |
| --- | --- |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | Credentials for S3/MinIO |
| `AWS_REGION` | Defaults to `us-east-1` |
| `S3_ENDPOINT` | Optional; set to `http://localhost:9000` for MinIO |
| `VIDEO_JOBS_BUCKET` | Bucket that stores audio, images, and generated MP4 files |

Create the bucket manually (or via `aws s3api create-bucket` / MinIO UI) before uploading.

## Upload workflow
1. Stimulus `upload_controller` asks `/uploads/presign` (JSON) for a presigned POST.
2. Files are sent directly to storage; the resulting object key is stored in hidden fields.
3. Form submission stays HTML-first and enqueues `VideoJobProcessorJob`.

## Testing & quality
- Because Ruby 4.0 ships with Minitest 6, `bin/rails test` currently fails to discover specs. Until upstream fixes land, run the suite via `mise exec -- bundle exec ruby -Itest -e 'Dir["test/**/*_test.rb"].sort.each { |f| load File.expand_path(f) }'`.
- Tailwind builds run automatically when the suite boots; this ensures missing class definitions fail fast.
- RuboCop and Brakeman binstubs are available (`bin/rubocop`, `bin/brakeman`) if you need extra checks.

## Hotwire notes
- UI updates live inside Turbo Frames with `turbo_stream_from @video_job`.
- Polling fallback uses `status_poll_controller.js`; disable it via data attributes if ActionCable is available.
- Keep API responses minimal—HTML is the default contract for both the browser and Hotwire Native.
