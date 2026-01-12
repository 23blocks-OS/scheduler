import os from "os";
import type { NextApiRequest, NextApiResponse } from "next";

import { getVersionString } from "@calcom/lib/version";
import { prisma } from "@calcom/prisma";

interface DetailedCheck {
  status: boolean;
  response_time_ms: number;
}

interface DetailedHealthResponse {
  service: string;
  status: "ok" | "degraded";
  version: string;
  environment: string;
  timestamp: string;
  uptime_seconds: number;
  uptime_human: string;
  checks: {
    database: DetailedCheck;
    redis: DetailedCheck;
  };
  system: {
    node_version: string;
    pid: number;
    hostname: string;
  };
}

// Track process start time for uptime calculation
const processStartTime = Date.now();

/**
 * Detailed diagnostics endpoint - full health information
 *
 * Used by: NOC dashboards, Grafana, internal monitoring
 * Auth: Requires X-Api-Key header starting with 'hc_'
 * HTTP Status: 200 OK (or 401 if unauthorized)
 *
 * @see https://github.com/23blocks-OS/ai-maestro - NOC standard health endpoints
 */
export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  // Validate API key authentication
  const apiKey = req.headers["x-api-key"];
  if (!apiKey || typeof apiKey !== "string" || !apiKey.startsWith("hc_")) {
    return res.status(401).json({
      error: "Unauthorized",
      message: "Valid X-Api-Key header required (must start with 'hc_')",
    });
  }

  const checks: { database: DetailedCheck; redis: DetailedCheck } = {
    database: { status: false, response_time_ms: 0 },
    redis: { status: true, response_time_ms: 0 }, // Default true if not configured
  };

  // Check database connectivity with timing
  const dbStart = performance.now();
  try {
    await prisma.$queryRaw`SELECT 1`;
    checks.database.status = true;
  } catch {
    checks.database.status = false;
  }
  checks.database.response_time_ms = Math.round((performance.now() - dbStart) * 100) / 100;

  // Check Redis if configured (Upstash Redis)
  if (process.env.UPSTASH_REDIS_REST_URL && process.env.UPSTASH_REDIS_REST_TOKEN) {
    const redisStart = performance.now();
    try {
      const { Redis } = await import("@upstash/redis");
      const redis = Redis.fromEnv({ signal: () => AbortSignal.timeout(2000) });
      await redis.ping();
      checks.redis.status = true;
    } catch {
      checks.redis.status = false;
    }
    checks.redis.response_time_ms = Math.round((performance.now() - redisStart) * 100) / 100;
  }

  // Calculate uptime
  const uptimeMs = Date.now() - processStartTime;
  const uptimeSeconds = Math.floor(uptimeMs / 1000);
  const days = Math.floor(uptimeSeconds / 86400);
  const hours = Math.floor((uptimeSeconds % 86400) / 3600);
  const minutes = Math.floor((uptimeSeconds % 3600) / 60);
  const uptimeHuman = `${days}d ${hours}h ${minutes}m`;

  // Determine overall status (degraded if any check fails)
  const isOk = checks.database.status;
  const status = isOk ? "ok" : "degraded";

  // Determine environment
  const environment = process.env.NODE_ENV === "production" ? "production" : "stage";

  const response: DetailedHealthResponse = {
    service: "scheduler",
    status,
    version: `v${getVersionString()}`,
    environment,
    timestamp: new Date().toISOString(),
    uptime_seconds: uptimeSeconds,
    uptime_human: uptimeHuman,
    checks,
    system: {
      node_version: process.version,
      pid: process.pid,
      hostname: os.hostname(),
    },
  };

  res.status(200).json(response);
}
