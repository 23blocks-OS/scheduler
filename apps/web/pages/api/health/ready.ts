import type { NextApiRequest, NextApiResponse } from "next";

import { getVersionString } from "@calcom/lib/version";
import { prisma } from "@calcom/prisma";

interface HealthCheckResult {
  database: boolean;
  redis: boolean;
}

/**
 * Readiness check endpoint - "can the service handle requests?"
 *
 * Used by: ECS, Kubernetes readiness probes
 * Auth: None (completely public)
 * HTTP Status: 200 OK if ready, 503 Service Unavailable if not
 *
 * @see https://github.com/23blocks-OS/ai-maestro - NOC standard health endpoints
 */
export default async function handler(_req: NextApiRequest, res: NextApiResponse) {
  const checks: HealthCheckResult = {
    database: false,
    redis: true, // Redis is optional in this app (Upstash), default to true
  };

  // Check database connectivity
  try {
    await prisma.$queryRaw`SELECT 1`;
    checks.database = true;
  } catch {
    checks.database = false;
  }

  // Check Redis if configured (Upstash Redis is optional)
  if (process.env.UPSTASH_REDIS_REST_URL && process.env.UPSTASH_REDIS_REST_TOKEN) {
    try {
      const { Redis } = await import("@upstash/redis");
      const redis = Redis.fromEnv({ signal: () => AbortSignal.timeout(2000) });
      await redis.ping();
      checks.redis = true;
    } catch {
      checks.redis = false;
    }
  }

  const isReady = checks.database; // Database is required, Redis is optional
  const status = isReady ? 200 : 503;

  res.status(status).json({
    service: "scheduler",
    status: isReady ? "ready" : "not_ready",
    version: `v${getVersionString()}`,
    timestamp: new Date().toISOString(),
    checks,
  });
}
