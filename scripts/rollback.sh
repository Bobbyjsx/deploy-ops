#!/usr/bin/env bash
set -euo pipefail

# rollback.sh
# Performs a rollback to the previous image

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source "$DIR/../config/defaults.env"

# Just need HOST, USER, CONTAINER_NAME
CONTAINER_NAME="${CONTAINER_NAME:-$SERVICE_NAME}"
if [[ -z "${DEPLOY_HOST:-}" || -z "${DEPLOY_USER:-}" || -z "${CONTAINER_NAME:-}" ]]; then
    echo "ERROR: DEPLOY_HOST, DEPLOY_USER, and SERVICE_NAME (or CONTAINER_NAME) are required for rollback" >&2
    exit 1
fi

REMOTE_DIR="/opt/deploy/services/$CONTAINER_NAME"

echo "Attempting to find previous image for $CONTAINER_NAME..."
PREVIOUS_IMAGE=$("$DIR/remote.sh" exec "cat $REMOTE_DIR/previous_image 2>/dev/null || true")

if [[ -z "$PREVIOUS_IMAGE" ]]; then
    echo "ERROR: Could not determine previous image for $CONTAINER_NAME" >&2
    exit 1
fi

echo "Rolling back to previous image: $PREVIOUS_IMAGE"

# We can just extract DEPLOY_VERSION from PREVIOUS_IMAGE (after the colon)
# e.g., gcr.io/my-project/my-service:91ef23
OLD_VERSION="${PREVIOUS_IMAGE##*:}"
OLD_REGISTRY_IMAGE="${PREVIOUS_IMAGE%:*}"

# Set vars for deploy.sh
export DEPLOY_VERSION="$OLD_VERSION"
export REGISTRY_IMAGE="$OLD_REGISTRY_IMAGE"

# Re-run deploy.sh to redeploy that image
# Note: This will use the CURRENT environment variables in CircleCI for the old image
# which is usually what you want (e.g. secret rotation shouldn't break rollback).
"$DIR/deploy.sh"
