import Image from "next/image";
import Link from "next/link";
import { Suspense } from "react";

import { StoreBadges } from "@/components/site/store-badges";
import {
  getPublicFeatureGates,
  getStoreUrls,
} from "@/lib/supabase/public";

import { DownloadInviteClient } from "./download-invite-client";

export default async function DownloadPage() {
  const gates = await getPublicFeatureGates();
  const { ios, android } = getStoreUrls();
  const isComingSoon = gates.defaultMode === "coming_soon";

  return (
    <main className="relative flex min-h-full flex-1 items-center justify-center bg-background px-6 py-16">
      <div className="flex w-full max-w-md flex-col items-center gap-5 text-center">
        <Image
          src="/assets/logo/logo-dark.svg"
          alt="Ground Up"
          width={691}
          height={167}
          priority
          className="h-auto w-[min(80vw,280px)]"
        />
        <h1 className="text-2xl font-bold">
          {isComingSoon ? "Coming Soon — Early Access" : "Download Groundup Society"}
        </h1>
        <p className="text-sm text-muted-foreground whitespace-pre-line">
          {gates.comingSoonMessage}
        </p>

        <Suspense
          fallback={
            <p className="text-sm text-muted-foreground">Loading invite…</p>
          }
        >
          <DownloadInviteClient />
        </Suspense>

        <StoreBadges iosUrl={ios} androidUrl={android} />

        {!ios && !android ? (
          <p className="text-xs text-muted-foreground">
            App Store and Google Play links will appear here once published.
          </p>
        ) : null}

        <div className="flex gap-3 text-sm">
          <Link href="/" className="underline underline-offset-2">
            Home
          </Link>
          <Link href="/support" className="underline underline-offset-2">
            Support
          </Link>
          <Link href="/privacy" className="underline underline-offset-2">
            Privacy
          </Link>
          <Link href="/terms" className="underline underline-offset-2">
            Terms
          </Link>
        </div>
      </div>
    </main>
  );
}
