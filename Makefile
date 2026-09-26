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

build:
	@./scripts/build.sh

deploy: setup-network
	@./scripts/deploy.sh


rollback:
	@./scripts/rollback.sh
