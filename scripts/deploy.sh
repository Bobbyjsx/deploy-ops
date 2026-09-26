#!/usr/bin/env bash
set -euo pipefail

# deploy.sh
# Main deployment orchestration

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source "$DIR/../config/defaults.env"

"$DIR/validate.sh" deploy

CONTAINER_NAME="${CONTAINER_NAME:-$SERVICE_NAME}"
IMAGE_REF="${REGISTRY_IMAGE}:${DEPLOY_VERSION}"

echo "Starting deployment of $IMAGE_REF to $CONTAINER_NAME on $DEPLOY_HOST..."

# Generate runtime env file
umask 077
RUNTIME_ENV_TMP=$(mktemp)
cleanup_env() {
    rm -f "$RUNTIME_ENV_TMP"
}
trap cleanup_env EXIT

if [[ -n "${ENV_DECLARATION_FILE:-}" && -f "$ENV_DECLARATION_FILE" ]]; then
    echo "Generating environment from declaration file: $ENV_DECLARATION_FILE"
    while IFS='=' read -r key _; do
        # Ignore comments and empty lines
        if [[ -n "$key" && ! "$key" =~ ^# ]]; then
            # Trim whitespace
            key=$(echo "$key" | xargs)
            if [[ -n "${!key+x}" ]]; then
                echo "$key=${!key}" >> "$RUNTIME_ENV_TMP"
            fi
        fi
    done < "$ENV_DECLARATION_FILE"
elif [[ -n "${DEPLOY_ENV_FILE:-}" && -f "$DEPLOY_ENV_FILE" ]]; then
    echo "Using provided DEPLOY_ENV_FILE"
    cat "$DEPLOY_ENV_FILE" > "$RUNTIME_ENV_TMP"
fi

if [[ -n "${REGISTRY_PASSWORD:-}" && -n "${REGISTRY_USERNAME:-}" && -n "${REGISTRY:-}" ]]; then
    echo "Logging into remote registry..."
    echo "$REGISTRY_PASSWORD" | "$DIR/remote.sh" exec "docker login $REGISTRY -u '$REGISTRY_USERNAME' --password-stdin"
fi

# Ensure remote deployment directory structure
REMOTE_DIR="/opt/deploy/services/$CONTAINER_NAME"
echo "Setting up remote directory structure..."
"$DIR/remote.sh" exec "mkdir -p $REMOTE_DIR"

REMOTE_ENV_FILE="$REMOTE_DIR/.env"
if [[ -s "$RUNTIME_ENV_TMP" ]]; then
    echo "Copying environment file securely..."
    "$DIR/remote.sh" copy "$RUNTIME_ENV_TMP" "$REMOTE_ENV_FILE"
else
    echo "No environment variables to inject (or empty declaration)."
    "$DIR/remote.sh" exec "touch $REMOTE_ENV_FILE"
fi

# Prepare docker run options
DOCKER_RUN_OPTS="--name $CONTAINER_NAME --env-file $REMOTE_ENV_FILE --restart $RESTART_POLICY -d"

if [[ -n "${DOCKER_NETWORK:-}" ]]; then
    DOCKER_RUN_OPTS="$DOCKER_RUN_OPTS --network $DOCKER_NETWORK"
    echo "Ensuring docker network '$DOCKER_NETWORK' exists..."
    "$DIR/remote.sh" exec "docker network inspect $DOCKER_NETWORK >/dev/null 2>&1 || docker network create $DOCKER_NETWORK"
fi

if [[ -n "${HOST_PORT:-}" && -n "${CONTAINER_PORT:-}" ]]; then
    DOCKER_RUN_OPTS="$DOCKER_RUN_OPTS -p $HOST_PORT:$CONTAINER_PORT"
fi

# We use a container script remotely to pull, stop old, start new
echo "Transferring container execution script..."
"$DIR/remote.sh" copy "$DIR/container.sh" "$REMOTE_DIR/container.sh"
"$DIR/remote.sh" exec "chmod +x $REMOTE_DIR/container.sh"

echo "Executing container update remotely..."
# Pass as a single command string to SSH, wrapping DOCKER_RUN_OPTS in single quotes so the remote shell treats it as $4
"$DIR/remote.sh" exec "$REMOTE_DIR/container.sh update \"$CONTAINER_NAME\" \"$IMAGE_REF\" '$DOCKER_RUN_OPTS'"

# Health Check
echo "Transferring health-check script..."
"$DIR/remote.sh" copy "$DIR/health-check.sh" "$REMOTE_DIR/health-check.sh"
"$DIR/remote.sh" exec "chmod +x $REMOTE_DIR/health-check.sh"

echo "Running health check..."
"$DIR/remote.sh" exec "$REMOTE_DIR/health-check.sh \"$CONTAINER_NAME\" \"${HEALTHCHECK_URL:-}\" \"${HEALTHCHECK_TIMEOUT:-30}\" \"${HEALTHCHECK_RETRIES:-3}\""

echo "Deployment completed successfully for $CONTAINER_NAME ($IMAGE_REF)"
