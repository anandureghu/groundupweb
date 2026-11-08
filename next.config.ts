import type { NextConfig } from "next";
import path from "path";
import { fileURLToPath } from "url";

const configDir = path.dirname(fileURLToPath(import.meta.url));

const nextConfig: NextConfig = {
  // Parent dirs have other lockfiles (e.g. ~/bun.lock); pin Turbopack to this app
  // so error.tsx / global-error.tsx resolve in the React Client Manifest.
  turbopack: {
    root: configDir,
  },
};

export default nextConfig;
