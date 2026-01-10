import type { NextApiRequest, NextApiResponse } from "next";

import { getVersionInfo } from "@calcom/lib/version";

/**
 * Health check endpoint with version information
 *
 * Returns:
 * - status: "healthy" if the service is running
 * - version: Semantic version string (e.g., "0.1.0")
 * - build: Git commit hash
 * - buildDate: ISO timestamp of when the image was built
 */
export default function handler(_req: NextApiRequest, res: NextApiResponse) {
  const versionInfo = getVersionInfo();

  res.status(200).json({
    status: "healthy",
    version: versionInfo.version,
    major: versionInfo.major,
    minor: versionInfo.minor,
    patch: versionInfo.patch,
    build: versionInfo.build,
    buildDate: versionInfo.buildDate,
    timestamp: new Date().toISOString(),
  });
}
