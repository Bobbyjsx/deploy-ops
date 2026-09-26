#!/usr/bin/env bash
set -euo pipefail

# setup-tailscale.sh
# Establishes an ephemeral Tailscale connection for deployment

if [[ "${SKIP_TAILSCALE:-false}" == "true" ]]; then
    echo "SKIP_TAILSCALE is true. Skipping Tailscale ephemeral setup."
    exit 0
fi

if [[ -z "${TAILSCALE_AUTH_KEY:-}" ]]; then
    echo "ERROR: TAILSCALE_AUTH_KEY not set. Deployment cannot establish secure connection." >&2
    exit 1
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
