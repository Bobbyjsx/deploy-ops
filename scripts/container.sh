#!/usr/bin/env bash
set -euo pipefail

# container.sh
# Runs ON THE REMOTE VM to manage container lifecycle

ACTION="${1:-}"
CONTAINER_NAME="${2:-}"
IMAGE_REF="${3:-}"
DOCKER_RUN_OPTS="${4:-}"

REMOTE_DIR="/opt/deploy/services/$CONTAINER_NAME"

update_container() {
    echo "[REMOTE] Pulling image: $IMAGE_REF"
    docker pull "$IMAGE_REF"

    PREVIOUS_IMAGE=""
    if docker inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
        PREVIOUS_IMAGE=$(docker inspect --format='{{.Config.Image}}' "$CONTAINER_NAME")
        echo "[REMOTE] Container $CONTAINER_NAME already exists."
        echo "[REMOTE] Stopping and removing old container (was running $PREVIOUS_IMAGE)..."
        docker stop "$CONTAINER_NAME" || true
        docker rm -f "$CONTAINER_NAME" || true
        
        # Save previous image reference for rollback
        echo "$PREVIOUS_IMAGE" > "$REMOTE_DIR/previous_image"
    else
        echo "[REMOTE] Container $CONTAINER_NAME does not exist. Creating new."
    fi

    # Save current image reference
    echo "$IMAGE_REF" > "$REMOTE_DIR/current_image"

    echo "[REMOTE] Starting new container..."
    # DOCKER_RUN_OPTS is provided as a single string, we eval it carefully or just run it unquoted if it's safe.
    # Actually, DOCKER_RUN_OPTS could be multiple words. We should unquote it safely but since it's controlled by our script it's ok.
    # To be safer, we can pass options differently, or just use eval.
    # Since we control DOCKER_RUN_OPTS construction, let's use eval but ensure it's not containing arbitrary user input.
    # Or just let bash split on spaces:
    # shellcheck disable=SC2086
    docker run $DOCKER_RUN_OPTS "$IMAGE_REF"
    
    echo "[REMOTE] Container $CONTAINER_NAME started."
}

rollback_container() {
    if [[ ! -f "$REMOTE_DIR/previous_image" ]]; then
        echo "[REMOTE] ERROR: No previous image found for rollback." >&2
        exit 1
    fi
    PREV_IMAGE=$(cat "$REMOTE_DIR/previous_image")
    
    if [[ "$PREV_IMAGE" != "$IMAGE_REF" ]]; then
        echo "[REMOTE] ERROR: Requested rollback image $IMAGE_REF does not match previous image $PREV_IMAGE" >&2
        # Allow override? For now, strict.
        # Actually, maybe the rollback just deploys a specific image tag.
        # Let's just use the update flow for rollback too, but specify the image!
        # The user's instruct say: make rollback DEPLOY_VERSION=91ef23
        # So rollback is essentially just an update to an older version. We don't even need a separate function if we just use update!
        exit 1
    fi
    # If we get here, we're essentially just re-deploying. We don't need a special rollback function here.
}

case "$ACTION" in
    update)
        update_container
        ;;
    *)
        echo "[REMOTE] ERROR: Invalid action '$ACTION' passed to container.sh." >&2
        exit 1
        ;;
esac
