# deploy-ops

Generic Build and Deployment Operations Repository. 

This repository acts as the deployment abstraction layer for our applications. It provides generic deployment commands that application repositories invoke from CI (e.g. CircleCI), removing the need for a central service registry and keeping application-specific logic out of deployment infrastructure.

## Architecture

The target deployment VMs are entirely private and secured by **Tailscale**. There are no publicly exposed SSH ports.

```text
Application Repository (CircleCI)
        |
        | 1. clone deploy-ops
        | 2. make build (Docker build & push to Registry)
        | 3. make setup-network (Establishes ephemeral Tailscale connection)
        | 4. make deploy (SSH execution over Tailscale)
        v
  [Tailscale Private Network]
        |
        v
    Private VM
        |
        | pulls image -> Docker Container
```

## Required Environment Variables

### Core
- `SERVICE_NAME`: The name of the service (e.g. `identity-service`)
- `IMAGE_NAME`: (Optional) Used to build the image name.
- `DEPLOY_VERSION`: The version to deploy (e.g. `abc1234` git hash). **Do not use `latest`**.
- `REGISTRY_IMAGE`: The full registry repository (e.g., `gcr.io/my-project/identity-service`)

### Remote Deployment & Tailscale
- `TAILSCALE_AUTH_KEY`: Pre-approved ephemeral auth key to join the Tailscale network.
- `DEPLOY_HOST`: Remote VM's Tailscale IP or MagicDNS hostname.
- `DEPLOY_USER`: Remote VM SSH user.

### Environment Handling (Secrets)
Applications can pass configuration using either:
- `ENV_DECLARATION_FILE`: Path to a file (like `.env.example`) containing variable names. The variables are fetched from the current environment (e.g., CircleCI context) and securely injected.
- `DEPLOY_ENV_FILE`: Direct path to a pre-generated runtime `.env` file.

Secrets are handled securely via temporary files and copied directly into the remote VM without ever printing them to CI logs.

### Network and Ports
- `DOCKER_NETWORK`: Target docker network (default: `bridge`)
- `HOST_PORT` & `CONTAINER_PORT`: Ports to expose locally on the VM (ingress is typically handled separately, e.g. via Cloudflare Tunnels).

### Health Checks
- `HEALTHCHECK_URL`: HTTP URL to ping after container start.
- `HEALTHCHECK_TIMEOUT` & `HEALTHCHECK_RETRIES`: Configuration for health check.

## Commands

### `make validate`
Validates that required environment variables for build and deploy stages exist.

### `make setup-network`
Installs Tailscale and authenticates as an ephemeral node using `$TAILSCALE_AUTH_KEY`. (Automatically called by `make deploy`).

### `make build`
1. Validates build inputs.
2. Builds the Docker image from `$DOCKERFILE` in `$BUILD_CONTEXT`.
3. Tags image with `$DEPLOY_VERSION`.
4. Pushes to the registry.

### `make deploy`
1. Validates deployment inputs.
2. Resolves secrets and environment variables.
3. SSH into remote host over Tailscale.
4. Pulls image, stops previous container securely.
5. Re-runs container with proper network, restart policies, and environment file.
6. Performs Health Check.

### `make rollback`
Finds the previous image version on the VM and re-deploys it safely. Requires `DEPLOY_VERSION` parameter to match the old version.

## CircleCI Integration Example

Inside your application repository `.circleci/config.yml`:

```yaml
version: 2.1

commands:
  build-and-deploy:
    description: "Clone deploy-ops, build Docker image, and deploy to private VM"
    steps:
      - checkout
      - run:
          name: Clone deploy-ops
          command: git clone --branch main https://github.com/<your-org>/deploy-ops.git
      - run:
          name: Build and Deploy
          # Note: The deploy-ops scripts will read variables declared in .env.example
          # from the CI context and pass them to the container securely.
          command: |
            cd deploy-ops
            make build
            make deploy

jobs:
  deploy-staging:
    docker:
      - image: cimg/base:stable
    environment:
      SERVICE_NAME: example-service
      REGISTRY_IMAGE: gcr.io/project/example-service
      ENV_DECLARATION_FILE: .env.example
    steps:
      - run: echo "export DEPLOY_VERSION=$CIRCLE_SHA1" >> $BASH_ENV
      - build-and-deploy

  deploy-prod:
    docker:
      - image: cimg/base:stable
    environment:
      SERVICE_NAME: example-service
      REGISTRY_IMAGE: gcr.io/project/example-service
      ENV_DECLARATION_FILE: .env.example
    steps:
      - run: echo "export DEPLOY_VERSION=$CIRCLE_SHA1" >> $BASH_ENV
      - build-and-deploy

workflows:
  build-and-deploy:
    jobs:
      - deploy-staging:
          filters:
            branches:
              only: develop
          context:
            - deploy-ops-staging # Contains staging infra (DEPLOY_HOST, TAILSCALE_AUTH_KEY, etc.)
            - app-staging        # Contains staging app secrets (DB_PASSWORD, API_KEY, etc.)
            
      - deploy-prod:
          filters:
            branches:
              only: main
          context:
            - deploy-ops-prod    # Contains prod infra (DEPLOY_HOST, TAILSCALE_AUTH_KEY, etc.)
            - app-prod           # Contains prod app secrets (DB_PASSWORD, API_KEY, etc.)
```

**Contexts Required:**
You must attach the corresponding `deploy-ops` infrastructure context in your CircleCI workflow to provide `TAILSCALE_AUTH_KEY`, `DEPLOY_HOST`, and `DEPLOY_USER`. Additionally, attach any application-specific secret contexts required for your `.env` variables.

## Security Considerations
- `set -euo pipefail` is used strictly.
- SSH keys and secrets are created via temporary `umask 077` files.
- Command-line arguments use arrays where applicable, avoiding blind `eval` of untrusted inputs.
- All deployment traffic traverses the encrypted Tailscale mesh network; no ports are exposed publicly.
