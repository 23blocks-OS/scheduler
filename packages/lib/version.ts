/**
 * Application version information
 * This file is dynamically generated during Docker build
 * @see Dockerfile for version embedding logic
 */

interface VersionInfo {
  major: number;
  minor: number;
  patch: number;
  build: string;
  buildDate: string;
}

// Default version (overwritten during Docker build)
const defaultVersion: VersionInfo = {
  major: 0,
  minor: 1,
  patch: 0,
  build: "development",
  buildDate: new Date().toISOString(),
};

// Try to load version from config file (generated at build time)
let versionData: VersionInfo;

try {
  // In Docker builds, config/version.json is generated with actual values
  // eslint-disable-next-line @typescript-eslint/no-var-requires, @typescript-eslint/no-require-imports
  versionData = require("../../config/version.json") as VersionInfo;
} catch {
  // Fallback to default in development
  versionData = defaultVersion;
}

export const APP_VERSION = versionData;

/**
 * Returns version as a semver string (e.g., "0.1.0")
 */
export function getVersionString(): string {
  return `${APP_VERSION.major}.${APP_VERSION.minor}.${APP_VERSION.patch}`;
}

/**
 * Returns full version info for health endpoints
 */
export function getVersionInfo(): VersionInfo & { version: string } {
  return {
    ...APP_VERSION,
    version: getVersionString(),
  };
}
