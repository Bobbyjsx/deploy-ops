#!/usr/bin/env bash
set -euo pipefail

# setup-tailscale.sh
# Establishes an ephemeral Tailscale connection for deployment

if [[ -z "${TAILSCALE_AUTH_KEY:-}" ]]; then
    echo "TAILSCALE_AUTH_KEY not set. Skipping Tailscale ephemeral setup (assuming host is directly reachable)."
    exit 0
fi

if ! command -v tailscale &> /dev/null; then
    echo "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
fi

echo "Authenticating Tailscale (ephemeral node)..."
# Use sudo only if necessary (CircleCI standard executor allows passwordless sudo)
SUDO="sudo"
if [[ "$EUID" -eq 0 ]]; then
    SUDO=""
fi

$SUDO tailscale up \
    --authkey="${TAILSCALE_AUTH_KEY}" \
    --hostname="circleci-deploy-ops-${SERVICE_NAME:-unknown}" \
    --ephemeral \
    --accept-routes

echo "Waiting for Tailscale connection to establish..."
$SUDO tailscale status
echo "Tailscale connection established."
