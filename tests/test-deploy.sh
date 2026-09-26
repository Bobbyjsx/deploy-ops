#!/usr/bin/env bash
set -euo pipefail

# test-deploy.sh
export SERVICE_NAME="test-service"
export DEPLOY_VERSION="test-abc"
export REGISTRY_IMAGE="dummy-registry.local/test-image"
export DEPLOY_HOST="fake-host"
export DEPLOY_USER="fake-user"
export CONTAINER_NAME="test-container"
export ENV_DECLARATION_FILE=$(mktemp)
export DB_PASS="secret_password"
export SKIP_TAILSCALE="true"
echo "DB_PASS=" > "$ENV_DECLARATION_FILE"

# Mock remote/ssh commands
TMP_BIN=$(mktemp -d)
cat > "$TMP_BIN/ssh" << 'EOF'
#!/bin/bash
echo "[MOCK SSH] $@"
EOF
cat > "$TMP_BIN/scp" << 'EOF'
#!/bin/bash
echo "[MOCK SCP] $@"
EOF
cat > "$TMP_BIN/docker" << 'EOF'
#!/bin/bash
echo "[MOCK DOCKER] $@"
EOF
chmod +x "$TMP_BIN/ssh" "$TMP_BIN/scp" "$TMP_BIN/docker"
export PATH="$TMP_BIN:$PATH"

make deploy

rm -rf "$TMP_BIN"
rm -f "$ENV_DECLARATION_FILE"
echo "test-deploy passed"
