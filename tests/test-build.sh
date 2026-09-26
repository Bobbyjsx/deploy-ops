#!/usr/bin/env bash
set -euo pipefail

# test-build.sh
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
export SERVICE_NAME="test-service"
export IMAGE_NAME="test-image"
export DEPLOY_VERSION="test-abc"
export REGISTRY_IMAGE="dummy-registry.local/test-image"
export DOCKERFILE="$DIR/dummy.Dockerfile"
export BUILD_CONTEXT="$DIR"
export PUSH_LATEST="false"

echo "FROM scratch" > "$DOCKERFILE"

# Mock registry login / push to avoid real network / docker daemon interaction if needed,
# or just run it with a local docker daemon if available.
# We will mock the registry script and docker command.

# Create a fake docker command in PATH
TMP_BIN=$(mktemp -d)
cat > "$TMP_BIN/docker" << 'EOF'
#!/bin/bash
echo "[MOCK DOCKER] $@"
EOF
chmod +x "$TMP_BIN/docker"
export PATH="$TMP_BIN:$PATH"

make build

rm -rf "$TMP_BIN"
rm -f "$DOCKERFILE"
echo "test-build passed"
