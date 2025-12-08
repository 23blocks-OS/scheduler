# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is Cal.com (formerly Calendso), an open-source Calendly successor built as a monorepo scheduling infrastructure. It's a TypeScript/Next.js application with:
- Multi-workspace monorepo structure using Yarn workspaces and Turbo
- Prisma ORM with PostgreSQL database
- tRPC for type-safe APIs
- Tailwind CSS for styling
- Multiple apps including web, API v1/v2, and UI playground

## Key Commands

### Development
```bash
# Start development server (requires .env setup)
yarn dev

# Start with database setup (Docker required)
yarn dx

# Run specific workspaces
yarn dev:api       # Web + API development
yarn dev:console   # Web + Console development
yarn dev:all       # All apps development
```

### Testing
```bash
# Run unit tests
yarn test

# Run E2E tests (requires database seeding)
yarn test-e2e

# Run playwright tests
yarn test-playwright

# Open test UI
yarn test:ui
```

### Database
```bash
# Run Prisma migrations
yarn workspace @calcom/prisma db-migrate   # Development
yarn workspace @calcom/prisma db-deploy    # Production

# Seed database
yarn db-seed

# Open Prisma Studio
yarn db-studio
```

### Build & Deployment
```bash
# Build for production
yarn build

# Start production server
yarn start

# Type checking
yarn type-check

# Linting
yarn lint
yarn lint:fix
```

### App Store Management
```bash
# Create new app
yarn create-app

# Edit existing app
yarn edit-app

# Build app store
yarn app-store:build
```

## Architecture

### Monorepo Structure
- **apps/**: Main applications
  - `web/`: Primary Cal.com web application (Next.js)
  - `api/v1/`: REST API v1
  - `api/v2/`: NestJS-based API v2
  - `ui-playground/`: Component documentation
- **packages/**: Shared packages
  - `prisma/`: Database schema and migrations
  - `trpc/`: tRPC router definitions
  - `features/`: Feature modules (bookings, auth, etc.)
  - `app-store/`: Integration apps
  - `embeds/`: Embedding functionality
  - `emails/`: Email templates and utilities
  - `platform/`: Platform SDK and atoms

### Key Configuration Files
- Database schema: `packages/prisma/schema.prisma`
- Turbo configuration: `turbo.json`
- Environment setup: `.env.example` (copy to `.env`)
- App Store config: `.env.appStore.example` (copy to `.env.appStore`)

### Critical Environment Variables
Required for basic operation:
- `DATABASE_URL`: PostgreSQL connection string
- `NEXTAUTH_SECRET`: Authentication secret (generate with `openssl rand -base64 32`)
- `CALENDSO_ENCRYPTION_KEY`: Encryption key (generate with `openssl rand -base64 32`)
- `NEXT_PUBLIC_WEBAPP_URL`: Application URL

### Testing Strategy
- Unit tests: Vitest (`*.test.ts`, `*.test.tsx`)
- E2E tests: Playwright (`playwright/*.e2e.ts`)
- Test utilities in `tests/libs/`
- Mock data in `tests/libs/mockData.ts`

### API Structure
- v1 API: Traditional REST endpoints in `apps/api/v1/`
- v2 API: NestJS-based modern API in `apps/api/v2/`
- tRPC: Type-safe internal APIs in `packages/trpc/`

### Feature Organization
Major features are modularized in `packages/features/`:
- `bookings/`: Booking flow and management
- `auth/`: Authentication and authorization
- `ee/`: Enterprise edition features
- `insights/`: Analytics and reporting
- `workflows/`: Automation workflows

### Development Tips
1. Always run `yarn` after pulling changes to ensure dependencies are updated
2. Use `yarn dx` for quick local development with Docker-managed PostgreSQL
3. Database migrations must be run after schema changes
4. The monorepo uses Turbo for build orchestration - respect dependency order
5. Feature flags and enterprise features are managed through licensing
6. Test files should be colocated with source files when possible