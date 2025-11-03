FROM node:18 AS builder

WORKDIR /calcom

ARG NEXT_PUBLIC_LICENSE_CONSENT
ARG NEXT_PUBLIC_WEBSITE_TERMS_URL
ARG NEXT_PUBLIC_WEBSITE_PRIVACY_POLICY_URL
ARG CALCOM_TELEMETRY_DISABLED
ARG DATABASE_URL
ARG NEXTAUTH_SECRET=secret
ARG CALENDSO_ENCRYPTION_KEY=secret
ARG MAX_OLD_SPACE_SIZE=12288
ARG NEXT_PUBLIC_API_V2_URL

ENV NEXT_PUBLIC_WEBAPP_URL=http://NEXT_PUBLIC_WEBAPP_URL_PLACEHOLDER \
    NEXT_PUBLIC_API_V2_URL=${NEXT_PUBLIC_API_V2_URL:-http://NEXT_PUBLIC_WEBAPP_URL_PLACEHOLDER/api/v2} \
    NEXT_PUBLIC_LICENSE_CONSENT=$NEXT_PUBLIC_LICENSE_CONSENT \
    NEXT_PUBLIC_WEBSITE_TERMS_URL=$NEXT_PUBLIC_WEBSITE_TERMS_URL \
    NEXT_PUBLIC_WEBSITE_PRIVACY_POLICY_URL=$NEXT_PUBLIC_WEBSITE_PRIVACY_POLICY_URL \
    CALCOM_TELEMETRY_DISABLED=$CALCOM_TELEMETRY_DISABLED \
    DATABASE_URL=$DATABASE_URL \
    DATABASE_DIRECT_URL=$DATABASE_URL \
    NEXTAUTH_SECRET=${NEXTAUTH_SECRET} \
    CALENDSO_ENCRYPTION_KEY=${CALENDSO_ENCRYPTION_KEY} \
    NODE_OPTIONS=--max-old-space-size=${MAX_OLD_SPACE_SIZE} \
    BUILD_STANDALONE=true

COPY package.json yarn.lock .yarnrc.yml playwright.config.ts turbo.json i18n.json ./
COPY .yarn ./.yarn
COPY apps/web ./apps/web
COPY apps/api ./apps/api
COPY packages ./packages
COPY tests ./tests

RUN yarn config set httpTimeout 1200000
RUN npx turbo prune --scope=@calcom/web --scope=@calcom/api --docker
RUN yarn install

RUN echo "Building @calcom/trpc..." && \
    NODE_OPTIONS="--max-old-space-size=8192" yarn workspace @calcom/trpc run build

RUN echo "Building @calcom/embed-core..." && \
    NODE_OPTIONS="--max-old-space-size=8192" yarn --cwd packages/embeds/embed-core workspace @calcom/embed-core run build

RUN echo "Building @calcom/web..." && \
    NODE_OPTIONS="--max-old-space-size=8192" yarn workspace @calcom/web run build

RUN echo "Building @calcom/api..." && \
    NODE_OPTIONS="--max-old-space-size=8192" yarn workspace @calcom/api run build

# Build and make embed servable from web/public/embed folder
# Build with proper memory management and error handling
# RUN set -e && \
#     echo "Building @calcom/trpc..." && \
#     NODE_OPTIONS="--max-old-space-size=8192" yarn workspace @calcom/trpc run build && \
#     echo "Building @calcom/embed-core..." && \
#     NODE_OPTIONS="--max-old-space-size=8192" yarn --cwd packages/embeds/embed-core workspace @calcom/embed-core run build && \
#     echo "Building @calcom/web..." && \
#     NODE_OPTIONS="--max-old-space-size=8192" yarn workspace @calcom/web run build
# # RUN yarn workspace @calcom/trpc run build
# RUN yarn --cwd packages/embeds/embed-core workspace @calcom/embed-core run build
# RUN yarn --cwd apps/web workspace @calcom/web run build --verbose

# RUN yarn plugin import workspace-tools && \
#     yarn workspaces focus --all --production
RUN rm -rf node_modules/.cache .yarn/cache apps/web/.next/cache

FROM node:18 AS builder-two

WORKDIR /calcom
ARG NEXT_PUBLIC_WEBAPP_URL=http://localhost:3000

ENV NODE_ENV=production

COPY package.json .yarnrc.yml turbo.json i18n.json ./
COPY .yarn ./.yarn
COPY --from=builder calcom/yarn.lock ./yarn.lock
COPY --from=builder calcom/node_modules ./node_modules
COPY --from=builder calcom/packages ./packages
COPY --from=builder calcom/apps/web ./apps/web
COPY --from=builder calcom/apps/api ./apps/api
COPY --from=builder calcom/packages/prisma/schema.prisma ./prisma/schema.prisma
COPY scripts scripts

# Save value used during this build stage. If NEXT_PUBLIC_WEBAPP_URL and BUILT_NEXT_PUBLIC_WEBAPP_URL differ at
# run-time, then start.sh will find/replace static values again.
ENV NEXT_PUBLIC_WEBAPP_URL=$NEXT_PUBLIC_WEBAPP_URL \
    BUILT_NEXT_PUBLIC_WEBAPP_URL=$NEXT_PUBLIC_WEBAPP_URL

RUN chmod +x scripts/replace-placeholder.sh && \
    scripts/replace-placeholder.sh http://NEXT_PUBLIC_WEBAPP_URL_PLACEHOLDER ${NEXT_PUBLIC_WEBAPP_URL}

FROM node:18 AS runner


WORKDIR /calcom
COPY --from=builder-two /calcom ./ 
ARG NEXT_PUBLIC_WEBAPP_URL=http://localhost:3000
ENV NEXT_PUBLIC_WEBAPP_URL=$NEXT_PUBLIC_WEBAPP_URL \
    BUILT_NEXT_PUBLIC_WEBAPP_URL=$NEXT_PUBLIC_WEBAPP_URL

ENV NODE_ENV=production
EXPOSE 3000 3003

HEALTHCHECK --interval=30s --timeout=30s --retries=5 \
    CMD wget --spider http://localhost:3000 || exit 1

RUN chmod +x /calcom/scripts/start.sh
CMD ["/calcom/scripts/start.sh"]