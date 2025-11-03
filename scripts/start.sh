#!/bin/bash
set -x

# Replace the statically built BUILT_NEXT_PUBLIC_WEBAPP_URL with run-time NEXT_PUBLIC_WEBAPP_URL
# NOTE: if these values are the same, this will be skipped.
scripts/replace-placeholder.sh "$BUILT_NEXT_PUBLIC_WEBAPP_URL" "$NEXT_PUBLIC_WEBAPP_URL"

scripts/wait-for-it.sh ${DATABASE_HOST} -- echo "database is up"
npx prisma migrate deploy --schema /calcom/packages/prisma/schema.prisma
npx ts-node --transpile-only /calcom/packages/prisma/seed-app-store.ts

# Start both web (port 3000) and API v1 (port 3003) services
echo "Starting Cal.com Web App on port 3000..."
yarn workspace @calcom/web start &
WEB_PID=$!

echo "Starting Cal.com API v1 on port 3003..."
yarn workspace @calcom/api start &
API_PID=$!

# Function to handle shutdown gracefully
shutdown() {
  echo "Shutting down services..."
  kill $WEB_PID $API_PID 2>/dev/null
  wait $WEB_PID $API_PID 2>/dev/null
  exit 0
}

trap shutdown SIGTERM SIGINT

# Wait for both processes
wait -n $WEB_PID $API_PID