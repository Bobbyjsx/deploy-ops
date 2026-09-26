#!/usr/bin/env bash
set -euo pipefail

# build.sh
# Handles docker image build

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source "$DIR/../config/defaults.env"

"$DIR/validate.sh" build
"$DIR/registry.sh" login

IMAGE_REF="${REGISTRY_IMAGE}:${DEPLOY_VERSION}"

echo "Building Docker image: $IMAGE_REF"
echo "Dockerfile: $DOCKERFILE"
echo "Context: $BUILD_CONTEXT"

docker build \
    -f "$DOCKERFILE" \
    -t "$IMAGE_REF" \
    "$BUILD_CONTEXT"

"$DIR/registry.sh" push "$IMAGE_REF"

# Optional: Push latest tag if requested
if [[ "${PUSH_LATEST:-false}" == "true" ]]; then
    LATEST_REF="${REGISTRY_IMAGE}:latest"
    echo "Pushing latest tag: $LATEST_REF"
    docker tag "$IMAGE_REF" "$LATEST_REF"
    "$DIR/registry.sh" push "$LATEST_REF"
fi

echo "Build and push successful for $IMAGE_REF"
