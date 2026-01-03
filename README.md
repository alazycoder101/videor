# Videor

Hotwire-first Rails 8 application that stitches audio + cover art into shareable MP4s. It uses Turbo Streams for live status, direct-to-storage uploads, and Sidekiq + ffmpeg for rendering.

## Local development

Toolchain, environment variables, and workflow steps live in [`docs/development.md`](docs/development.md). It covers running `mise exec -- bin/dev`, managing Redis/MinIO, and executing the custom test runner required on Ruby 4.0.

## Container image

The Dockerfile in the project root builds the production image (ffmpeg included) and the GitHub Actions workflow automatically publishes tagged builds to GHCR. See [`docs/containers.md`](docs/containers.md) for details on local builds, runtime environment variables, and how the CI pipeline is configured.

For containerized development, copy `.env.compose.example` to `.env.compose`, populate secrets, and run `docker compose up --build`. For Kubernetes/k3s deployments, use the Helm chart under `chart/` or the raw manifests in `k8s/` (see `docs/containers.md` for details).
