#!/usr/bin/env bash
set -euo pipefail

# remote.sh
# Handles SSH execution to remote host securely

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source "$DIR/../config/defaults.env"

if [[ -z "${DEPLOY_HOST:-}" || -z "${DEPLOY_USER:-}" ]]; then
    echo "ERROR: DEPLOY_HOST and DEPLOY_USER are required for remote execution" >&2
    exit 1
fi

SSH_OPTS=(-p "${DEPLOY_PORT:-22}")

# Secure Host Key Checking
if [[ -n "${DEPLOY_HOST_KEY:-}" ]]; then
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    if ! grep -q "$DEPLOY_HOST_KEY" ~/.ssh/known_hosts 2>/dev/null; then
        echo "$DEPLOY_HOST_KEY" >> ~/.ssh/known_hosts
    fi
    chmod 600 ~/.ssh/known_hosts
    SSH_OPTS+=("-o" "StrictHostKeyChecking=yes")
else
    # Fallback for environments lacking the explicit host key, with loud warning.
    # Over a verified Tailscale network this MITM risk is mitigated, but not eliminated.
    echo "WARNING: DEPLOY_HOST_KEY is not set. Falling back to StrictHostKeyChecking=no." >&2
    SSH_OPTS+=("-o" "StrictHostKeyChecking=no" "-o" "UserKnownHostsFile=/dev/null")
fi

if [[ -n "${DEPLOY_SSH_KEY:-}" ]]; then
    # Create temporary file securely for SSH private key
    umask 077
    SSH_KEY_TMP=$(mktemp)
    # Write exactly the content without interpretation
    cat <<< "$DEPLOY_SSH_KEY" > "$SSH_KEY_TMP"
    SSH_OPTS+=("-i" "$SSH_KEY_TMP")
fi

cleanup() {
    if [[ -n "${SSH_KEY_TMP:-}" && -f "$SSH_KEY_TMP" ]]; then
        rm -f "$SSH_KEY_TMP"
    fi
}
trap cleanup EXIT

ACTION="${1:-}"

if [[ "$ACTION" == "exec" ]]; then
    shift
    ssh "${SSH_OPTS[@]}" "${DEPLOY_USER}@${DEPLOY_HOST}" "$@"
elif [[ "$ACTION" == "copy" ]]; then
    SRC="$2"
    DEST="$3"
    scp "${SSH_OPTS[@]}" "$SRC" "${DEPLOY_USER}@${DEPLOY_HOST}:$DEST"
else
    echo "ERROR: Invalid action '$ACTION' passed to remote.sh. Expected exec or copy." >&2
    exit 1
fi
