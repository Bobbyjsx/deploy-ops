#!/usr/bin/env bash
set -euo pipefail

# registry.sh
# Handles docker registry operations

ACTION="${1:-}"
IMAGE="${2:-}"

registry_login() {
    # If REGISTRY_USERNAME and REGISTRY_PASSWORD are set, use standard docker login
    if [[ -n "${REGISTRY_USERNAME:-}" && -n "${REGISTRY_PASSWORD:-}" ]]; then
        echo "Logging into registry via standard docker login..."
        echo "$REGISTRY_PASSWORD" | docker login "${REGISTRY:-}" -u "$REGISTRY_USERNAME" --password-stdin
    else
        echo "Skipping explicit registry login. Assuming ambient credentials (e.g., GCE metadata or CircleCI contexts)."
    fi
}

registry_push() {
    if [[ -z "$IMAGE" ]]; then
        echo "ERROR: Image required for push" >&2
        exit 1
    fi
    echo "Pushing image: $IMAGE"
    docker push "$IMAGE"
}

case "$ACTION" in
    login)
        registry_login
        ;;
    push)
        registry_push
        ;;
    *)
        echo "ERROR: Invalid action '$ACTION' passed to registry.sh. Expected login or push." >&2
        exit 1
        ;;
esac
