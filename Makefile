# Makefile for Cal.com Scheduler Docker Setup

# Version and tagging
VERSION_MAJOR ?= 0
VERSION_MINOR ?= 0
VERSION_PATCH ?= 5
VERSION ?= v$(VERSION_MAJOR).$(VERSION_MINOR).$(VERSION_PATCH)

# Registry configuration
REGISTRY_URL ?= 663969591440.dkr.ecr.us-east-2.amazonaws.com
AWS_REGION ?= us-east-2
AWS_PROFILE ?= staging.23blocks

# Image name
IMAGE_NAME = scheduler

# ECR repository names
STAGING_REPO = $(REGISTRY_URL)/staging-23blocks
PROD_REPO = $(REGISTRY_URL)/production-23blocks

# Build arguments
BUILD_DATE := $(shell date -u +'%Y-%m-%dT%H:%M:%SZ')
GIT_COMMIT := $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
GIT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
BUILD_NUMBER := $(shell git rev-list --count HEAD 2>/dev/null || echo "0")

# Docker build arguments for Cal.com
DOCKER_BUILD_ARGS = \
	--build-arg BUILD_DATE=$(BUILD_DATE) \
	--build-arg GIT_COMMIT=$(GIT_COMMIT) \
	--build-arg CALCOM_TELEMETRY_DISABLED=1

# Version management
.PHONY: version version-bump-patch version-bump-minor version-bump-major

version:
	@echo "Current version: $(VERSION)"
	@echo "Build: $(BUILD_NUMBER)"
	@echo "Branch: $(GIT_BRANCH)"
	@echo "Commit: $(GIT_COMMIT)"

version-bump-patch:
	@echo "Bumping patch version..."
	$(eval VERSION_PATCH := $(shell echo $$(($(VERSION_PATCH)+1))))
	@echo "New version: v$(VERSION_MAJOR).$(VERSION_MINOR).$(VERSION_PATCH)"

version-bump-minor:
	@echo "Bumping minor version..."
	$(eval VERSION_MINOR := $(shell echo $$(($(VERSION_MINOR)+1))))
	$(eval VERSION_PATCH := 0)
	@echo "New version: v$(VERSION_MAJOR).$(VERSION_MINOR).$(VERSION_PATCH)"

version-bump-major:
	@echo "Bumping major version..."
	$(eval VERSION_MAJOR := $(shell echo $$(($(VERSION_MAJOR)+1))))
	$(eval VERSION_MINOR := 0)
	$(eval VERSION_PATCH := 0)
	@echo "New version: v$(VERSION_MAJOR).$(VERSION_MINOR).$(VERSION_PATCH)"

# ECR Authentication
.PHONY: ecr-login ecr-create-repos

ecr-login:
	@echo "Logging into AWS ECR: $(REGISTRY_URL) with profile: $(AWS_PROFILE)"
	aws ecr get-login-password --region $(AWS_REGION) --profile $(AWS_PROFILE) | docker login --username AWS --password-stdin $(REGISTRY_URL)

ecr-create-repos:
	@echo "Creating ECR repositories if they don't exist..."
	-aws ecr create-repository --repository-name staging-23blocks --region $(AWS_REGION) --profile $(AWS_PROFILE) 2>/dev/null || echo "Staging repo already exists"
	-aws ecr create-repository --repository-name production-23blocks --region $(AWS_REGION) --profile $(AWS_PROFILE) 2>/dev/null || echo "Production repo already exists"
	@echo "Repositories ready"

# Staging commands
.PHONY: staging-build staging-push staging-deploy

staging-build:
	@echo "Building scheduler image for staging..."
	@echo "Version: $(VERSION)"
	@echo "Git Commit: $(GIT_COMMIT)"
	@echo "Build Date: $(BUILD_DATE)"
	docker build \
		$(DOCKER_BUILD_ARGS) \
		-f dockerfile \
		-t $(IMAGE_NAME):staging \
		-t $(IMAGE_NAME):$(VERSION) \
		.
	@echo "Tagging images for ECR..."
	docker tag $(IMAGE_NAME):staging $(STAGING_REPO):scheduler-staging-$(VERSION)
	docker tag $(IMAGE_NAME):staging $(STAGING_REPO):scheduler-latest
	@echo "Images built and tagged successfully:"
	@echo "  Local: $(IMAGE_NAME):staging"
	@echo "  Local: $(IMAGE_NAME):$(VERSION)"
	@echo "  ECR: $(STAGING_REPO):scheduler-staging-$(VERSION)"
	@echo "  ECR: $(STAGING_REPO):scheduler-latest"

staging-push:
	@if [ -z "$(REGISTRY_URL)" ]; then \
		echo "Error: REGISTRY_URL is not set"; \
		exit 1; \
	fi
	@echo "Pushing to staging registry: $(STAGING_REPO)"
	docker push $(STAGING_REPO):scheduler-staging-$(VERSION)
	docker push $(STAGING_REPO):scheduler-latest
	@echo "Images pushed successfully:"
	@echo "  - $(STAGING_REPO):scheduler-staging-$(VERSION)"
	@echo "  - $(STAGING_REPO):scheduler-latest"

staging-deploy: ecr-login ecr-create-repos staging-build staging-push
	@echo "Staging deployment completed successfully!"
	@echo "Image: $(STAGING_REPO):scheduler-staging-$(VERSION)"

# Production commands
.PHONY: prod-build prod-push prod-deploy

prod-build:
	@echo "Building scheduler image for production..."
	@echo "Version: $(VERSION)"
	@echo "Git Commit: $(GIT_COMMIT)"
	@echo "Build Date: $(BUILD_DATE)"
	docker build \
		$(DOCKER_BUILD_ARGS) \
		-f dockerfile \
		-t $(IMAGE_NAME):production \
		-t $(IMAGE_NAME):$(VERSION)-prod \
		.
	@echo "Tagging images for ECR..."
	docker tag $(IMAGE_NAME):production $(PROD_REPO):scheduler-production-$(VERSION)
	docker tag $(IMAGE_NAME):production $(PROD_REPO):scheduler-latest
	@echo "Images built and tagged successfully:"
	@echo "  Local: $(IMAGE_NAME):production"
	@echo "  Local: $(IMAGE_NAME):$(VERSION)-prod"
	@echo "  ECR: $(PROD_REPO):scheduler-production-$(VERSION)"
	@echo "  ECR: $(PROD_REPO):scheduler-latest"

prod-push:
	@if [ -z "$(REGISTRY_URL)" ]; then \
		echo "Error: REGISTRY_URL is not set"; \
		exit 1; \
	fi
	@echo "Pushing to production registry: $(PROD_REPO)"
	docker push $(PROD_REPO):scheduler-production-$(VERSION)
	docker push $(PROD_REPO):scheduler-latest
	@echo "Images pushed successfully:"
	@echo "  - $(PROD_REPO):scheduler-production-$(VERSION)"
	@echo "  - $(PROD_REPO):scheduler-latest"

prod-deploy: ecr-login ecr-create-repos prod-build prod-push
	@echo "Production deployment completed successfully!"
	@echo "Image: $(PROD_REPO):scheduler-production-$(VERSION)"

# Local development commands
.PHONY: local-build local-run local-stop local-shell

local-build:
	@echo "Building scheduler image locally..."
	docker build \
		$(DOCKER_BUILD_ARGS) \
		-f dockerfile \
		-t $(IMAGE_NAME):local \
		.

local-run:
	@echo "Starting scheduler container..."
	docker run -d \
		--name scheduler-local \
		-p 3000:3000 \
		--env-file .env \
		$(IMAGE_NAME):local

local-stop:
	@echo "Stopping scheduler container..."
	-docker stop scheduler-local
	-docker rm scheduler-local

local-shell:
	@echo "Opening shell in scheduler container..."
	docker exec -it scheduler-local sh

# Database commands (for migrations and seeding)
.PHONY: db-migrate db-seed db-studio

db-migrate:
	@echo "Running database migrations..."
	yarn workspace @calcom/prisma db-migrate

db-deploy:
	@echo "Deploying database schema (production)..."
	yarn workspace @calcom/prisma db-deploy

db-seed:
	@echo "Seeding database..."
	yarn db-seed

db-studio:
	@echo "Opening Prisma Studio..."
	yarn db-studio

# Utility commands
.PHONY: clean list-images help

clean:
	@echo "Cleaning up Docker resources..."
	docker system prune -f
	docker volume prune -f

list-images:
	@echo "Current scheduler images:"
	@docker images | grep -E "scheduler|$(REGISTRY_URL)" | sort

help:
	@echo "Cal.com Scheduler Makefile Commands:"
	@echo ""
	@echo "Version Management:"
	@echo "  make version              - Show current version info"
	@echo "  make version-bump-patch   - Bump patch version"
	@echo "  make version-bump-minor   - Bump minor version"
	@echo "  make version-bump-major   - Bump major version"
	@echo ""
	@echo "ECR Setup:"
	@echo "  make ecr-login           - Login to AWS ECR"
	@echo "  make ecr-create-repos    - Create ECR repositories"
	@echo ""
	@echo "Staging Deployment:"
	@echo "  make staging-build       - Build staging image"
	@echo "  make staging-push        - Push staging image to ECR"
	@echo "  make staging-deploy      - Build and deploy to staging (full process)"
	@echo ""
	@echo "Production Deployment:"
	@echo "  make prod-build          - Build production image"
	@echo "  make prod-push           - Push production image to ECR"
	@echo "  make prod-deploy         - Build and deploy to production (full process)"
	@echo ""
	@echo "Local Development:"
	@echo "  make local-build         - Build local Docker image"
	@echo "  make local-run           - Run scheduler container locally"
	@echo "  make local-stop          - Stop local container"
	@echo "  make local-shell         - Open shell in container"
	@echo ""
	@echo "Database:"
	@echo "  make db-migrate          - Run database migrations (dev)"
	@echo "  make db-deploy           - Deploy database schema (prod)"
	@echo "  make db-seed             - Seed database"
	@echo "  make db-studio           - Open Prisma Studio"
	@echo ""
	@echo "Utilities:"
	@echo "  make clean               - Clean Docker resources"
	@echo "  make list-images         - List scheduler images"
	@echo "  make help                - Show this help message"
	@echo ""
	@echo "Environment Variables:"
	@echo "  VERSION_MAJOR            - Major version (default: 1)"
	@echo "  VERSION_MINOR            - Minor version (default: 0)"
	@echo "  VERSION_PATCH            - Patch version (default: 0)"
	@echo "  REGISTRY_URL             - ECR registry URL"
	@echo "  AWS_REGION               - AWS region (default: us-east-2)"
	@echo "  AWS_PROFILE              - AWS profile (default: staging.23blocks)"
