#!/usr/bin/env bash
set -euo pipefail

# setup-tailscale.sh
# Establishes a Tailscale connection for deployment

if [[ "${SKIP_TAILSCALE:-false}" == "true" ]]; then
    echo "SKIP_TAILSCALE is true. Skipping Tailscale ephemeral setup."
    exit 0
fi

if [[ -z "${TAILSCALE_AUTH_KEY:-}" ]]; then
    echo "ERROR: TAILSCALE_AUTH_KEY not set. Deployment cannot establish secure connection." >&2
    exit 1
fi

SUDO="sudo"
if [[ "$EUID" -eq 0 ]]; then
    SUDO=""
fi

if ! command -v tailscale &> /dev/null; then
    echo "Installing Tailscale CLI..."
    curl -fsSL https://tailscale.com/install.sh | sh
fi

TS_SOCKET="/tmp/tailscaled.sock"

echo "Starting tailscaled..."
# Use in-memory state and predictable socket. Also enforce userspace networking for CI containers.
$SUDO tailscaled --state=mem: --socket="$TS_SOCKET" --tun=userspace-networking --socks5-server=localhost:1055 > /tmp/tailscaled.log 2>&1 &

echo "Waiting for tailscaled to start..."
attempt=1
max_attempts=10
while [ ! -S "$TS_SOCKET" ]; do
    if [[ $attempt -ge $max_attempts ]]; then
        echo "ERROR: tailscaled failed to start or create socket." >&2
        cat /tmp/tailscaled.log >&2
        exit 1
    fi
    sleep 1
    attempt=$((attempt + 1))
done

echo "Bringing up Tailscale..."
# Ephemeral property should be configured on the auth key itself, not passed via CLI flag
$SUDO tailscale --socket="$TS_SOCKET" up \
    --authkey="${TAILSCALE_AUTH_KEY}" \
    --hostname="circleci-deploy-ops-${SERVICE_NAME:-unknown}" \
    --accept-routes

echo "Tailscale connection established."
$SUDO tailscale --socket="$TS_SOCKET" status
$SUDO tailscale --socket="$TS_SOCKET" ip

# We alias tailscale or set TS_SOCKET environment variable so subsequent tailscale commands work if needed
# However, for ssh/scp, if tailscale provides standard TUN networking, regular ssh works.
