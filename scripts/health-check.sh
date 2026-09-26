#!/usr/bin/env bash
set -euo pipefail

# health-check.sh
# Runs ON THE REMOTE VM to verify container health

CONTAINER_NAME="${1:-}"
HEALTHCHECK_URL="${2:-}"
HEALTHCHECK_TIMEOUT="${3:-30}"
HEALTHCHECK_RETRIES="${4:-3}"

echo "[REMOTE] Verifying container is running..."
# Brief sleep to let container fail early if it's going to crash immediately
sleep 2

if ! docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" | grep -q "true"; then
    echo "[REMOTE] ERROR: Container $CONTAINER_NAME is not running." >&2
    docker logs --tail 50 "$CONTAINER_NAME"
    exit 1
fi

if [[ -z "$HEALTHCHECK_URL" ]]; then
    echo "[REMOTE] No HTTP health check URL provided. Assuming healthy since container is running."
    exit 0
fi

echo "[REMOTE] Waiting for HTTP health check at $HEALTHCHECK_URL ..."
attempt=1

while [ "$attempt" -le "$HEALTHCHECK_RETRIES" ]; do
    echo "[REMOTE] Health check attempt $attempt/$HEALTHCHECK_RETRIES..."
    # We use curl with timeout
    if curl --fail --silent --max-time "$HEALTHCHECK_TIMEOUT" "$HEALTHCHECK_URL" > /dev/null; then
        echo "[REMOTE] Health check passed!"
        exit 0
    fi
    echo "[REMOTE] Attempt $attempt failed. Waiting..."
    sleep 5
    attempt=$((attempt + 1))
done

echo "[REMOTE] ERROR: Health check failed after $HEALTHCHECK_RETRIES attempts." >&2
docker logs --tail 50 "$CONTAINER_NAME"
exit 1
