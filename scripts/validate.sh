#!/usr/bin/env bash
set -euo pipefail

# validate.sh
# Validates required environment variables for different stages

ACTION="${1:-}"

validate_build() {
    local missing=0
    local required_vars=("SERVICE_NAME" "IMAGE_NAME" "DEPLOY_VERSION" "REGISTRY_IMAGE")
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            echo "ERROR: $var is required for build" >&2
            missing=1
        fi
    done
    
    if [[ "$missing" -eq 1 ]]; then
        exit 1
    fi
    
    # Validate container name to avoid unsafe chars
    if [[ ! "$SERVICE_NAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "ERROR: SERVICE_NAME can only contain alphanumeric characters, hyphens, and underscores." >&2
        exit 1
    fi
}

validate_deploy() {
    local missing=0
    local required_vars=("SERVICE_NAME" "DEPLOY_VERSION" "REGISTRY_IMAGE" "DEPLOY_HOST" "DEPLOY_USER")
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            echo "ERROR: $var is required for deploy" >&2
            missing=1
        fi
    done
    
    if [[ "$missing" -eq 1 ]]; then
        exit 1
    fi
}

validate_rollback() {
    local missing=0
    local required_vars=("SERVICE_NAME" "DEPLOY_VERSION" "REGISTRY_IMAGE" "DEPLOY_HOST" "DEPLOY_USER")
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            echo "ERROR: $var is required for rollback (DEPLOY_VERSION is the target rollback version)" >&2
            missing=1
        fi
    done
    
    if [[ "$missing" -eq 1 ]]; then
        exit 1
    fi
}

case "$ACTION" in
    build)
        validate_build
        ;;
    deploy)
        validate_deploy
        ;;
    rollback)
        validate_rollback
        ;;
    *)
        echo "ERROR: Invalid action '$ACTION' passed to validate.sh. Expected build, deploy, or rollback." >&2
        exit 1
        ;;
esac
