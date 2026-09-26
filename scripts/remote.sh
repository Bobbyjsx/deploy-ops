#!/usr/bin/env bash
set -euo pipefail

# remote.sh
# Handles SSH execution to remote host securely over Tailscale

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source "$DIR/../config/defaults.env"

if [[ -z "${DEPLOY_HOST:-}" || -z "${DEPLOY_USER:-}" ]]; then
    echo "ERROR: DEPLOY_HOST and DEPLOY_USER are required for remote execution" >&2
    exit 1
fi

# Tailscale SSH replaces the need for key management and mitigates MITM directly over the Tailnet.
SSH_OPTS=(
    "-o" "StrictHostKeyChecking=no"
    "-o" "UserKnownHostsFile=/dev/null"
    "-o" "PasswordAuthentication=no"
    "-o" "IdentitiesOnly=yes" # Do not attempt to use local OpenSSH keys
    "-o" "ProxyCommand=nc -X 5 -x 127.0.0.1:1055 %h %p" # Route through Tailscale userspace proxy
)

ACTION="${1:-}"

if [[ "$ACTION" == "exec" ]]; then
    shift
    # Note: Double quotes ensure correct arg passing for remote execution
    ssh "${SSH_OPTS[@]}" "${DEPLOY_USER}@${DEPLOY_HOST}" "$@"
elif [[ "$ACTION" == "copy" ]]; then
    SRC="$2"
    DEST="$3"
    scp "${SSH_OPTS[@]}" "$SRC" "${DEPLOY_USER}@${DEPLOY_HOST}:$DEST"
else
    echo "ERROR: Invalid action '$ACTION' passed to remote.sh. Expected exec or copy." >&2
    exit 1
fi
