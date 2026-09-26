.PHONY: validate setup-network build deploy rollback test help

help:
	@echo "deploy-ops - Generic Build and Deployment Operations"
	@echo ""
	@echo "Usage:"
	@echo "  make validate       Validate environment configuration"
	@echo "  make setup-network  Establish Tailscale private network connection"
	@echo "  make build          Build and push Docker image"
	@echo "  make deploy         Deploy image to remote host via private network"
	@echo "  make rollback       Rollback to previous deployment"
	@echo "  make test           Run the mocked test suite"
	@echo ""

validate:
	@./scripts/validate.sh build
	@./scripts/validate.sh deploy

test:
	@./tests/test-build.sh
	@./tests/test-deploy.sh


setup-network:
	@./scripts/setup-tailscale.sh

teardown-network:
	@echo "Logging out of Tailscale to remove ephemeral node..."
	@sudo tailscale --socket=/tmp/tailscaled.sock logout || true

build:
	@./scripts/build.sh

deploy: setup-network
	@./scripts/deploy.sh; \
	EXIT_CODE=$$?; \
	$(MAKE) teardown-network; \
	exit $$EXIT_CODE


rollback:
	@./scripts/rollback.sh
