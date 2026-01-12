#!/bin/bash
set -x

# Replace the statically built placeholders with run-time environment variables
# NOTE: if values are the same, replacements will be skipped.

# Core URL
scripts/replace-placeholder.sh "$BUILT_NEXT_PUBLIC_WEBAPP_URL" "$NEXT_PUBLIC_WEBAPP_URL"

# White-label branding (runtime configurable per customer)
if [ -n "$NEXT_PUBLIC_APP_NAME" ]; then
    scripts/replace-placeholder.sh "NEXT_PUBLIC_APP_NAME_PLACEHOLDER" "$NEXT_PUBLIC_APP_NAME"
fi

if [ -n "$NEXT_PUBLIC_COMPANY_NAME" ]; then
    scripts/replace-placeholder.sh "NEXT_PUBLIC_COMPANY_NAME_PLACEHOLDER" "$NEXT_PUBLIC_COMPANY_NAME"
fi

if [ -n "$NEXT_PUBLIC_SUPPORT_MAIL_ADDRESS" ]; then
    scripts/replace-placeholder.sh "NEXT_PUBLIC_SUPPORT_MAIL_ADDRESS_PLACEHOLDER" "$NEXT_PUBLIC_SUPPORT_MAIL_ADDRESS"
fi

if [ -n "$NEXT_PUBLIC_SENDGRID_SENDER_NAME" ]; then
    scripts/replace-placeholder.sh "NEXT_PUBLIC_SENDER_NAME_PLACEHOLDER" "$NEXT_PUBLIC_SENDGRID_SENDER_NAME"
fi

if [ -n "$NEXT_PUBLIC_SENDER_ID" ]; then
    scripts/replace-placeholder.sh "NEXT_PUBLIC_SENDER_ID_PLACEHOLDER" "$NEXT_PUBLIC_SENDER_ID"
fi

if [ -n "$NEXT_PUBLIC_WEBSITE_URL" ]; then
    scripts/replace-placeholder.sh "NEXT_PUBLIC_WEBSITE_URL_PLACEHOLDER" "$NEXT_PUBLIC_WEBSITE_URL"
fi

scripts/wait-for-it.sh ${DATABASE_HOST} -- echo "database is up"
npx prisma migrate deploy --schema /calcom/packages/prisma/schema.prisma
npx ts-node --transpile-only /calcom/packages/prisma/seed-app-store.ts

# Start both web (port 3000) and API v1 (port 3003) services
echo "Starting Scheduler Web App on port 3000..."
npx turbo run start --filter="@calcom/web" &
WEB_PID=$!

echo "Starting Scheduler API v1 on port 3003..."
yarn workspace @calcom/api run start &
API_PID=$!

# Wait for both processes
wait $WEB_PID $API_PID
