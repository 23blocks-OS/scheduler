import type { NextApiRequest, NextApiResponse } from "next";

import { getVersionString } from "@calcom/lib/version";

/**
 * Liveness check endpoint - "is the process running?"
 *
 * Used by: ALB Target Groups, Cloudflare, status pages
 * Auth: None (completely public)
 * HTTP Status: Always 200 OK
 *
 * @see https://github.com/23blocks-OS/ai-maestro - NOC standard health endpoints
 */
export default function handler(_req: NextApiRequest, res: NextApiResponse) {
  res.status(200).json({
    service: "scheduler",
    status: "ok",
    version: `v${getVersionString()}`,
    timestamp: new Date().toISOString(),
  });
}
