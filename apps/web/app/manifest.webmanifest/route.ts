import { NextResponse } from "next/server";

import { APP_NAME } from "@calcom/lib/constants";

/**
 * Dynamic web manifest that uses configurable APP_NAME for white-labeling
 */
export async function GET() {
  const manifest = {
    name: APP_NAME,
    short_name: APP_NAME,
    description: "Scheduling infrastructure for absolutely everyone.",
    icons: [
      {
        src: "/api/logo?type=android-chrome-192",
        sizes: "192x192",
        type: "image/png",
      },
      {
        src: "/api/logo?type=android-chrome-256",
        sizes: "256x256",
        type: "image/png",
      },
    ],
    theme_color: "#ffffff",
    background_color: "#ffffff",
    display_override: ["minimal-ui"],
    display: "standalone",
    scope: "/",
    start_url: "/",
  };

  return NextResponse.json(manifest, {
    headers: {
      "Content-Type": "application/manifest+json",
      "Cache-Control": "public, max-age=3600",
    },
  });
}
