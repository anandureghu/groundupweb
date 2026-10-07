import Image from "next/image";
import Link from "next/link";

import { StoreBadges } from "@/components/site/store-badges";
import { Button } from "@/components/ui/button";
import {
  getPublicFeatureGates,
  getStoreUrls,
} from "@/lib/supabase/public";

export default async function Home() {
  const gates = await getPublicFeatureGates();
  const { ios, android } = getStoreUrls();
  const isComingSoon = gates.defaultMode === "coming_soon";

  const footerLinks = [
    { label: "Privacy", href: "/privacy" },
    { label: "Terms", href: "/terms" },
    { label: "Download", href: "/download" },
  ];

  return (
    <main className="relative flex min-h-full flex-1 items-center justify-center bg-background px-6 py-16">
      <div className="flex w-full max-w-lg flex-col items-center justify-center gap-5 text-center">
        <Image
          src="/assets/logo/logo-dark.svg"
          alt="Ground Up"
          width={691}
          height={167}
          priority
          className="h-auto w-[min(80vw,320px)]"
        />
        <h1 className="text-2xl font-bold">
          {isComingSoon ? "Coming Soon" : "Groundup Society"}
        </h1>
        <div className="space-y-2">
          <p className="text-sm text-center text-muted-foreground whitespace-pre-line">
            {gates.comingSoonMessage}
          </p>
          {isComingSoon ? (
            <p className="text-sm text-center text-muted-foreground">
              Early joiners can download the app below and sign up with a staff
              invite.
            </p>
          ) : null}
        </div>

        <StoreBadges iosUrl={ios} androidUrl={android} />

        {!ios && !android ? (
          <p className="text-xs text-muted-foreground">
            Store links coming soon. Have an invite?{" "}
            <Link href="/download" className="underline underline-offset-2">
              Open the download page
            </Link>
            .
          </p>
        ) : (
          <Link
            href="/download"
            className="text-xs underline underline-offset-2 text-muted-foreground"
          >
            Have a staff invite code? Continue here
          </Link>
        )}
      </div>
      <div className="absolute bottom-4 left-1/2 -translate-x-1/2 flex gap-2">
        {footerLinks.map((link) => (
          <Link href={link.href} key={link.label}>
            <Button variant="link" className="uppercase">
              {link.label}
            </Button>
          </Link>
        ))}
      </div>
    </main>
  );
}
