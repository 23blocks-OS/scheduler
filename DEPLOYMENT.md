# Deployment Guide for Cal.com Scheduler

This guide covers deploying the Cal.com Scheduler application to AWS using Docker and ECR.

## Prerequisites

- Docker installed and running
- AWS CLI configured with appropriate credentials
- AWS profile configured (default: `staging.23blocks`)
- Access to AWS ECR repository

## Quick Start

### 1. Login to ECR

```bash
make ecr-login
```

### 2. Deploy to Staging

```bash
make staging-deploy
```

This command will:
- Build the Docker image
- Tag it with version and latest tags
- Push to ECR staging repository

### 3. Deploy to Production

```bash
make prod-deploy
```

## Makefile Commands

### Version Management

```bash
# Show current version
make version

# Bump versions
make version-bump-patch  # 1.0.0 -> 1.0.1
make version-bump-minor  # 1.0.0 -> 1.1.0
make version-bump-major  # 1.0.0 -> 2.0.0
```

### Staging Deployment

```bash
# Build staging image only
make staging-build

# Push to ECR (requires build first)
make staging-push

# Full deployment (login + build + push)
make staging-deploy
```

### Production Deployment

```bash
# Build production image only
make prod-build

# Push to ECR (requires build first)
make prod-push

# Full deployment (login + build + push)
make prod-deploy
```

### Local Development

```bash
# Build local image
make local-build

# Run container locally (requires .env file)
make local-run

# Stop local container
make local-stop

# Access container shell
make local-shell
```

### Database Management

```bash
# Run migrations (development)
make db-migrate

# Deploy schema (production)
make db-deploy

# Seed database
make db-seed

# Open Prisma Studio
make db-studio
```

### Utilities

```bash
# List all scheduler images
make list-images

# Clean up Docker resources
make clean

# Show help
make help
```

## Configuration

### Environment Variables

The Makefile uses the following default configuration:

```makefile
REGISTRY_URL = 663969591440.dkr.ecr.us-east-2.amazonaws.com
AWS_REGION = us-east-2
AWS_PROFILE = staging.23blocks
```

You can override these when running commands:

```bash
# Use different AWS profile
make staging-deploy AWS_PROFILE=production.23blocks

# Use different region
make staging-deploy AWS_REGION=us-west-2

# Custom version
make staging-deploy VERSION_PATCH=5
```

### Version Numbering

The default version is `v1.0.0`. Update the version in the Makefile:

```makefile
VERSION_MAJOR ?= 1
VERSION_MINOR ?= 0
VERSION_PATCH ?= 0
```

Or override when building:

```bash
make staging-build VERSION_MAJOR=2 VERSION_MINOR=1 VERSION_PATCH=3
```

## Image Tags

Each build creates multiple tags:

**Staging:**
- `staging-23blocks:scheduler-v1.0.0` (version-specific)
- `staging-23blocks:scheduler-latest` (latest)

**Production:**
- `production-23blocks:scheduler-v1.0.0` (version-specific)
- `production-23blocks:scheduler-latest` (latest)

## Workflow Examples

### Standard Staging Deployment

```bash
# 1. Ensure you're on the right branch
git checkout main

# 2. Check current version
make version

# 3. Bump version if needed
make version-bump-patch

# 4. Deploy to staging
make staging-deploy
```

### Production Release

```bash
# 1. Ensure staging is tested and working
# 2. Create a release branch or tag
git checkout -b release/v1.0.0

# 3. Update version in Makefile
# Edit VERSION_MAJOR, VERSION_MINOR, VERSION_PATCH

# 4. Deploy to production
make prod-deploy

# 5. Tag the release
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

### Hotfix Deployment

```bash
# 1. Create hotfix branch
git checkout -b hotfix/critical-fix

# 2. Make your changes
# ... fix the issue ...

# 3. Bump patch version
make version-bump-patch

# 4. Deploy to staging first
make staging-deploy

# 5. Test in staging
# ... verify the fix ...

# 6. Deploy to production
make prod-deploy
```

## Troubleshooting

### ECR Login Issues

If you encounter authentication errors:

```bash
# Check AWS credentials
aws sts get-caller-identity --profile staging.23blocks

# Manually login to ECR
aws ecr get-login-password --region us-east-2 --profile staging.23blocks | \
  docker login --username AWS --password-stdin 663969591440.dkr.ecr.us-east-2.amazonaws.com
```

### Build Failures

If the Docker build fails:

```bash
# Check Docker is running
docker info

# Clean up Docker resources
make clean

# Try building again with verbose output
docker build -f dockerfile -t scheduler:test . --progress=plain
```

### Image Not Found in ECR

Create the ECR repositories if they don't exist:

```bash
make ecr-create-repos
```

## CI/CD Integration

You can integrate these commands into GitHub Actions or other CI/CD pipelines:

```yaml
# Example GitHub Action
- name: Deploy to Staging
  run: |
    make ecr-login
    make staging-build
    make staging-push
  env:
    AWS_PROFILE: staging.23blocks
```

## Environment-Specific Configuration

### Required Environment Variables for Runtime

Ensure your deployment environment has these variables set:

- `DATABASE_URL` - PostgreSQL connection string
- `NEXTAUTH_SECRET` - Authentication secret
- `CALENDSO_ENCRYPTION_KEY` - Encryption key
- `NEXT_PUBLIC_WEBAPP_URL` - Application URL

See `.env.example` for the complete list.

## Next Steps

After deploying to ECR:

1. Update your ECS task definition or Kubernetes deployment to use the new image
2. Deploy to your container orchestration platform (ECS, EKS, etc.)
3. Run database migrations if needed
4. Monitor application logs and health checks
