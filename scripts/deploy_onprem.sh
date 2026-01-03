#!/usr/bin/env bash
set -euo pipefail

ENV_FILE=${ENV_FILE:-.deploy.env}

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE. Copy .deploy.env.example and fill in your values." >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

: "${REGISTRY_IMAGE:?REGISTRY_IMAGE is required (e.g. ghcr.io/org/videor)}"
: "${IMAGE_TAG:=onprem}"
: "${HELM_RELEASE:=videor}"
: "${RAILS_MASTER_KEY:?Set RAILS_MASTER_KEY in $ENV_FILE}"
: "${AWS_ACCESS_KEY_ID:?Set AWS_ACCESS_KEY_ID in $ENV_FILE}"
: "${AWS_SECRET_ACCESS_KEY:?Set AWS_SECRET_ACCESS_KEY in $ENV_FILE}"
: "${VIDEO_JOBS_BUCKET:?Set VIDEO_JOBS_BUCKET in $ENV_FILE}"
: "${DATABASE_URL:?Set DATABASE_URL in $ENV_FILE}"
: "${REDIS_URL:?Set REDIS_URL in $ENV_FILE}"
: "${AWS_REGION:=us-east-1}"
: "${STORAGE_HOST_ALLOWLIST:?Set STORAGE_HOST_ALLOWLIST in $ENV_FILE}"

if [[ -n "${KUBE_CONTEXT:-}" ]]; then
  kubectl config use-context "$KUBE_CONTEXT"
fi

echo "Building image ${REGISTRY_IMAGE}:${IMAGE_TAG}…"
docker build -t "${REGISTRY_IMAGE}:${IMAGE_TAG}" .

echo "Pushing image…"
docker push "${REGISTRY_IMAGE}:${IMAGE_TAG}"

echo "Deploying via Helm release ${HELM_RELEASE}…"
helm upgrade --install "$HELM_RELEASE" ./chart \
  --set image.repository="$REGISTRY_IMAGE" \
  --set image.tag="$IMAGE_TAG" \
  --set env.REDIS_URL="$REDIS_URL" \
  --set env.AWS_REGION="$AWS_REGION" \
  --set env.STORAGE_HOST_ALLOWLIST="$STORAGE_HOST_ALLOWLIST" \
  --set secrets.railsMasterKey="$RAILS_MASTER_KEY" \
  --set secrets.awsAccessKeyId="$AWS_ACCESS_KEY_ID" \
  --set secrets.awsSecretAccessKey="$AWS_SECRET_ACCESS_KEY" \
  --set secrets.videoJobsBucket="$VIDEO_JOBS_BUCKET" \
  --set secrets.databaseUrl="$DATABASE_URL"
