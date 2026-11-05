import type { NextRequest } from "next/server";

import { updateSession } from "@/lib/supabase/middleware";

// NOTE: Next.js 16 renamed the `middleware.ts` file convention to `proxy.ts`
// (middleware.ts still works but is deprecated and logs a warning — see
// node_modules/next/dist/docs/01-app/03-api-reference/03-file-conventions/proxy.md).
// This file is the Proxy equivalent of the standard @supabase/ssr middleware
// recipe: it refreshes the Supabase session cookie on every matched request.
export function proxy(request: NextRequest) {
  return updateSession(request);
}

export const config = {
  matcher: ["/admin/:path*"],
};
