# MCP JFrog Multi-Architecture Docker Build
#
# This Makefile provides targets for building and pushing multi-architecture
# Docker images using Docker Buildx.
#
# Usage:
#   make build          - Build and push multi-arch image
#   make build-local    - Build for local architecture only
#   make help           - Show all available targets

# Configuration - Override these as needed
IMAGE_REGISTRY ?= docker.io/your-registry
IMAGE_NAME ?= mcp-jfrog
VERSION ?= 0.0.1
FULL_IMAGE_NAME = $(IMAGE_REGISTRY)/$(IMAGE_NAME)

# Multi-architecture platforms
PLATFORMS = linux/amd64,linux/arm64

# Buildx builder name
BUILDER_NAME = mcp-jfrog-multiarch

.PHONY: build build-local setup-builder push run shell clean clean-builder help

# Build and push multi-arch image
build: setup-builder
	@echo "Building multi-arch image for platforms: $(PLATFORMS)"
	docker buildx build \
		--builder $(BUILDER_NAME) \
		--platform $(PLATFORMS) \
		--tag $(FULL_IMAGE_NAME):$(VERSION) \
		--tag $(FULL_IMAGE_NAME):latest \
		--push \
		.

# Build for local architecture only (faster for development)
build-local:
	@echo "Building image for local architecture..."
	docker build -t $(FULL_IMAGE_NAME):$(VERSION) -t $(FULL_IMAGE_NAME):latest .

# Ensure buildx builder exists
setup-builder:
	@if ! docker buildx inspect $(BUILDER_NAME) > /dev/null 2>&1; then \
		echo "Creating buildx builder: $(BUILDER_NAME)"; \
		docker buildx create --name $(BUILDER_NAME) --driver docker-container --bootstrap; \
	else \
		echo "Using existing buildx builder: $(BUILDER_NAME)"; \
	fi

# Push is an alias for build (buildx pushes during build)
push: build

# Run the container locally
run:
	@if [ -z "$(JFROG_URL)" ]; then \
		echo "Error: JFROG_URL environment variable is required"; \
		exit 1; \
	fi
	@if [ -z "$(JFROG_ACCESS_TOKEN)" ]; then \
		echo "Error: JFROG_ACCESS_TOKEN environment variable is required"; \
		exit 1; \
	fi
	docker run -it --rm \
		-e JFROG_URL=$(JFROG_URL) \
		-e JFROG_ACCESS_TOKEN=$(JFROG_ACCESS_TOKEN) \
		-p 8080:8080 \
		$(FULL_IMAGE_NAME):$(VERSION)

# Start interactive shell in container
shell:
	docker run -it --rm \
		-e JFROG_URL=$(JFROG_URL) \
		-e JFROG_ACCESS_TOKEN=$(JFROG_ACCESS_TOKEN) \
		$(FULL_IMAGE_NAME):$(VERSION) \
		/bin/sh

# Run tests
test:
	npm test

# Remove local images
clean:
	docker rmi $(FULL_IMAGE_NAME):$(VERSION) $(FULL_IMAGE_NAME):latest 2>/dev/null || true

# Remove buildx builder
clean-builder:
	docker buildx rm $(BUILDER_NAME) 2>/dev/null || true

# Show help
help:
	@echo "MCP JFrog Docker Build Targets"
	@echo ""
	@echo "Configuration (set via environment or make arguments):"
	@echo "  IMAGE_REGISTRY  - Docker registry (default: docker.io/your-registry)"
	@echo "  IMAGE_NAME      - Image name (default: mcp-jfrog)"
	@echo "  VERSION         - Image version tag (default: 0.0.1)"
	@echo ""
	@echo "Build targets:"
	@echo "  build           - Build and push multi-arch image (amd64 + arm64)"
	@echo "  build-local     - Build for local architecture only (faster)"
	@echo "  setup-builder   - Create/verify buildx builder exists"
	@echo "  push            - Alias for 'build'"
	@echo ""
	@echo "Run targets:"
	@echo "  run             - Run container (requires JFROG_URL, JFROG_ACCESS_TOKEN)"
	@echo "  shell           - Start interactive shell in container"
	@echo ""
	@echo "Other targets:"
	@echo "  test            - Run npm tests"
	@echo "  clean           - Remove local Docker images"
	@echo "  clean-builder   - Remove buildx builder"
	@echo "  help            - Show this help message"
	@echo ""
	@echo "Examples:"
	@echo "  make build IMAGE_REGISTRY=ghcr.io/myorg VERSION=1.0.0"
	@echo "  make build-local"
	@echo "  make run JFROG_URL=https://myinstance.jfrog.io JFROG_ACCESS_TOKEN=xxx"
